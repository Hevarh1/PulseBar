import SwiftUI
import ServiceManagement

/// System Settings–style grouped form. The window behind it is frosted glass
/// (see `SettingsWindowController`), so the form hides its own background.
public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var shortcut = DashboardShortcut.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Menu Bar Indicators") {
                Toggle("Show Temperature", isOn: $settings.showMenuBarTemperature)
                Toggle("Show CPU Usage (%)", isOn: $settings.showMenuBarCPU)
                Toggle("Show Memory Usage (%)", isOn: $settings.showMenuBarMemory)
                Toggle("Show Network Rate", isOn: $settings.showMenuBarNetwork)
                Toggle("Show Battery Level", isOn: $settings.showMenuBarBattery)
                Toggle("Show Uptime", isOn: $settings.showMenuBarUptime)
            }

            Section("Dashboard Cards") {
                Toggle("CPU Card", isOn: $settings.showCPUCard)
                Toggle("Memory Card", isOn: $settings.showMemoryCard)
                Toggle("Storage Card", isOn: $settings.showStorageCard)
                Toggle("Network Card", isOn: $settings.showNetworkCard)
                Toggle("GPU Card", isOn: $settings.showGPUCard)
                Toggle("Fan Card", isOn: $settings.showFanCard)
                Toggle("Mac Controls Grid", isOn: $settings.showUtilityGrid)
            }

            Section("General") {
                Picker("Update Interval", selection: $settings.samplingInterval) {
                    Text("0.5 second").tag(0.5)
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }
                .onChange(of: settings.samplingInterval) { _, _ in
                    // Open-tier interval is read from AppSettings; idle stays at 5s.
                    MetricsCoordinator.shared.restartSampling()
                }

                Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }

                Toggle(isOn: $settings.dashboardShortcutEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Dashboard Shortcut")
                            ShortcutKeycap(shortcut: DashboardShortcut.shortcut)
                        }
                        Text(shortcutCaption)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        if configureLaunchAtLogin(enabled: newValue) {
                            settings.launchAtLogin = newValue
                        }
                    }
                ))
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy")
                        Text("No network. No telemetry. No external downloads. Metrics and utilities stay on this Mac.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .scrollContentBackground(.hidden)
        .frame(width: 400, height: 560)
    }

    private var shortcutCaption: String {
        let keys = DashboardShortcut.shortcut.displayString
        if settings.dashboardShortcutEnabled && !shortcut.isRegistered {
            return "\(keys) couldn't be registered. Try turning it off and on again."
        }
        return "Press \(keys) in any app to show or hide the dashboard."
    }

    /// Returns false when registration is unsupported (e.g. `swift run` without a real .app bundle).
    @discardableResult
    private func configureLaunchAtLogin(enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }

        // `SMAppService.mainApp` only works for an installed app bundle, not a raw
        // SwiftPM executable under `.build/…`.
        let bundlePath = Bundle.main.bundleURL.path
        let isBundledApp = bundlePath.hasSuffix(".app") || bundlePath.contains(".app/")
        guard isBundledApp else {
            UtilityFeedback.showInfo(
                title: "Launch at Login Unavailable",
                message: "Run an installed PulseBar.app (not `swift run`) before enabling Launch at Login."
            )
            return false
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            UtilityFeedback.showInfo(
                title: "Launch at Login Failed",
                message: error.localizedDescription
            )
            return false
        }
    }
}
