import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Menu Bar Display
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Menu Bar Indicators")
                            .font(.system(size: 13, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Show Temperature", isOn: $settings.showMenuBarTemperature)
                            Toggle("Show CPU Usage (%)", isOn: $settings.showMenuBarCPU)
                            Toggle("Show Memory Usage (%)", isOn: $settings.showMenuBarMemory)
                            Toggle("Show Network Rate", isOn: $settings.showMenuBarNetwork)
                            Toggle("Show Battery Level", isOn: $settings.showMenuBarBattery)
                            Toggle("Show Uptime", isOn: $settings.showMenuBarUptime)
                        }
                        .toggleStyle(.checkbox)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }

                    // Visible Cards
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dashboard Cards")
                            .font(.system(size: 13, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("CPU Card", isOn: $settings.showCPUCard)
                            Toggle("Memory Card", isOn: $settings.showMemoryCard)
                            Toggle("Storage Card", isOn: $settings.showStorageCard)
                            Toggle("Network Card", isOn: $settings.showNetworkCard)
                            Toggle("GPU Card", isOn: $settings.showGPUCard)
                            Toggle("Fan Card", isOn: $settings.showFanCard)
                            Toggle("Mac Controls Grid", isOn: $settings.showUtilityGrid)
                        }
                        .toggleStyle(.checkbox)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }

                    // General Settings
                    VStack(alignment: .leading, spacing: 10) {
                        Text("General")
                            .font(.system(size: 13, weight: .semibold))

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Update Interval")
                                Spacer()
                                Picker("", selection: $settings.samplingInterval) {
                                    Text("0.5 second").tag(0.5)
                                    Text("1 second").tag(1.0)
                                    Text("2 seconds").tag(2.0)
                                    Text("5 seconds").tag(5.0)
                                }
                                .frame(width: 140)
                                .onChange(of: settings.samplingInterval) { _, _ in
                                    // Open-tier interval is read from AppSettings; idle stays at 5s.
                                    MetricsCoordinator.shared.restartSampling()
                                }
                            }

                            HStack {
                                Text("Temperature Unit")
                                Spacer()
                                Picker("", selection: $settings.temperatureUnit) {
                                    ForEach(TemperatureUnit.allCases) { unit in
                                        Text(unit.rawValue).tag(unit)
                                    }
                                }
                                .frame(width: 140)
                            }

                            Toggle("Launch at Login", isOn: Binding(
                                get: { settings.launchAtLogin },
                                set: { newValue in
                                    if configureLaunchAtLogin(enabled: newValue) {
                                        settings.launchAtLogin = newValue
                                    }
                                }
                            ))
                            .toggleStyle(.checkbox)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Privacy", systemImage: "lock.shield.fill")
                            .font(.system(size: 13, weight: .semibold))

                        Text("No network. No telemetry. No external downloads. Metrics and utilities stay on this Mac.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .padding(16)
            }
        }
        .frame(width: 360, height: 460)
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
