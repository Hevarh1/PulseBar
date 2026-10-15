import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject private var coordinator = MetricsCoordinator.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var pulse = false
    @State private var memoryFreeRequested = false

    private let columns = [
        GridItem(.flexible(), spacing: DesignTokens.gridSpacing),
        GridItem(.flexible(), spacing: DesignTokens.gridSpacing)
    ]

    public init() {}

    public var body: some View {
        let snapshot = coordinator.currentSnapshot

        VStack(spacing: 0) {
            header(snapshot: snapshot)

            Divider().opacity(0.28)

            VStack(spacing: DesignTokens.sectionSpacing) {
                LazyVGrid(columns: columns, spacing: DesignTokens.gridSpacing) {
                    if settings.showCPUCard {
                        cpuTile(snapshot)
                    }
                    if settings.showMemoryCard {
                        memoryTile(snapshot)
                    }
                    if settings.showNetworkCard {
                        networkTile(snapshot)
                    }
                    if settings.showStorageCard {
                        storageTile(snapshot)
                    }
                    if settings.showGPUCard {
                        gpuTile(snapshot)
                    }
                    if settings.showFanCard {
                        fanTile(snapshot)
                    }
                }

                if settings.showUtilityGrid {
                    UtilityGrid()
                }
            }
            .padding(10)
            .fixedSize(horizontal: false, vertical: true)

            Divider().opacity(0.28)
            footer
        }
        .frame(width: DesignTokens.popoverWidth)
        .background(
            reduceTransparency
                ? AnyView(Color(NSColor.windowBackgroundColor))
                : AnyView(Rectangle().fill(.ultraThinMaterial))
        )
        .animation(.snappy(duration: 0.35), value: coordinator.sampleTick)
        .onChange(of: coordinator.sampleTick) { _, _ in
            withAnimation(.easeOut(duration: 0.2)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeIn(duration: 0.55)) { pulse = false }
            }
        }
    }

    // MARK: - Header

    private func header(snapshot: SystemSnapshot) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if let appIcon = AppIcon.applicationImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("PulseBar")
                        .font(.system(size: 14, weight: .bold))
                    liveDot
                }
                Text(snapshot.cpu.chipModel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let temp = snapshot.thermal.temperatureCelsius {
                headerChip(
                    icon: "thermometer.medium",
                    text: Formatters.formatTemperature(temp, unit: settings.temperatureUnit),
                    color: thermalColor(snapshot.thermal.thermalState)
                )
            }

            if snapshot.battery.isPresent {
                headerChip(
                    icon: "battery.100",
                    text: "\(snapshot.battery.percentage)%",
                    color: snapshot.battery.percentage < 20 ? .red : .secondary
                )
            }

            headerChip(
                icon: "clock",
                text: Formatters.formatUptime(seconds: snapshot.uptime.uptimeSeconds),
                color: .secondary
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var liveDot: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(DesignTokens.accent)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 1.0 : 0.35)
                .scaleEffect(pulse ? 1.15 : 1.0)
            Text("LIVE")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(DesignTokens.accent.opacity(pulse ? 1 : 0.55))
                .tracking(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(DesignTokens.accent.opacity(0.12))
        .cornerRadius(5)
    }

    private func headerChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.28), value: text)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(6)
    }

    private var footer: some View {
        HStack {
            Button {
                SettingsWindowController.shared.showPreferences()
            } label: {
                Label("Preferences", systemImage: "gearshape")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.red.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Tiles

    private func cpuTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "CPU", icon: "cpu", accent: DesignTokens.accent) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    LiveMetricValue(Formatters.formatPercentage(snapshot.cpu.totalPercentage, precision: 0))
                    Spacer(minLength: 0)
                    Text("\(snapshot.cpu.coreCount)c")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                CPUStackedGraphView(
                    userPoints: snapshot.cpuUserHistory,
                    sysPoints: snapshot.cpuSystemHistory,
                    height: DesignTokens.graphHeightCPU
                )

                HStack {
                    legendDot(Color(red: 0.20, green: 0.60, blue: 1.0), "Usr \(Int(snapshot.cpu.userPercentage))%")
                    Spacer(minLength: 4)
                    legendDot(Color(red: 0.95, green: 0.30, blue: 0.30), "Sys \(Int(snapshot.cpu.systemPercentage))%")
                }
            }
        }
    }

    private func memoryTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "Memory", icon: "memorychip", accent: Color(red: 0.62, green: 0.42, blue: 1.0)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    LiveMetricValue(Formatters.formatPercentage(snapshot.memory.usedPercentage, precision: 0))
                    Spacer(minLength: 0)
                    Text(snapshot.memory.pressureLevel.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(pressureColor(snapshot.memory.pressureLevel))
                }

                GraphView(
                    dataPoints: snapshot.memoryHistory,
                    maxValue: 100,
                    strokeColor: Color(red: 0.62, green: 0.42, blue: 1.0),
                    gradientColors: [
                        Color(red: 0.62, green: 0.42, blue: 1.0).opacity(0.35),
                        Color(red: 0.62, green: 0.42, blue: 1.0).opacity(0)
                    ],
                    height: DesignTokens.graphHeightDefault
                )

                HStack {
                    Text("\(Formatters.formatBytes(snapshot.memory.usedBytes)) / \(Formatters.formatBytes(snapshot.memory.totalBytes))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Button {
                        _ = coordinator.freeUpMemory()
                        memoryFreeRequested = true
                        UtilityFeedback.playSuccess()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            memoryFreeRequested = false
                        }
                    } label: {
                        Text(memoryFreeRequested ? "Requested" : "Free")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(red: 0.62, green: 0.42, blue: 1.0))
                    }
                    .buttonStyle(.plain)
                    .disabled(memoryFreeRequested)
                }
            }
        }
    }

    private func networkTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "Network", icon: "network", accent: Color(red: 0.20, green: 0.78, blue: 0.55)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("↓")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(red: 0.20, green: 0.78, blue: 0.55))
                        LiveMetricValue(compactRate(snapshot.network.downloadBytesPerSec), size: 16)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("↑")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(DesignTokens.accent.opacity(0.75))
                        LiveMetricValue(compactRate(snapshot.network.uploadBytesPerSec), size: 16)
                    }
                }

                ZStack {
                    GraphView(
                        dataPoints: snapshot.networkDownHistory,
                        maxValue: coordinator.networkGraphMaxBytesPerSec,
                        strokeColor: Color(red: 0.20, green: 0.78, blue: 0.55),
                        gradientColors: [
                            Color(red: 0.20, green: 0.78, blue: 0.55).opacity(0.3),
                            .clear
                        ],
                        height: DesignTokens.graphHeightDefault
                    )
                    GraphView(
                        dataPoints: snapshot.networkUpHistory,
                        maxValue: coordinator.networkGraphMaxBytesPerSec,
                        strokeColor: DesignTokens.accent.opacity(0.7),
                        gradientColors: [.clear, .clear],
                        height: DesignTokens.graphHeightDefault
                    )
                }

                Text(snapshot.network.localIPAddress)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func storageTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "Storage", icon: "internaldrive", accent: Color(red: 0.20, green: 0.72, blue: 0.78)) {
            VStack(alignment: .leading, spacing: 8) {
                LiveMetricValue(Formatters.formatPercentage(snapshot.disk.usedPercentage, precision: 0))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(Color(red: 0.20, green: 0.72, blue: 0.78))
                            .frame(width: geo.size.width * CGFloat(min(1, max(0, snapshot.disk.usedPercentage / 100))))
                            .animation(.easeInOut(duration: 0.35), value: snapshot.disk.usedPercentage)
                    }
                }
                .frame(height: 6)

                Text("\(Formatters.formatDiskBytes(snapshot.disk.freeBytes)) free")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    Text("↓ \(compactRate(snapshot.disk.readBytesPerSec))")
                    Spacer()
                    Text("↑ \(compactRate(snapshot.disk.writeBytesPerSec))")
                }
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(.secondary)
                .monospacedDigit()
            }
        }
    }

    private func gpuTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "GPU", icon: "display", accent: Color.orange.opacity(0.9)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.gpu.modelName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Utilization unavailable")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func fanTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "Fan", icon: snapshot.fan.isFanless ? "fan.slash" : "fan", accent: Color.cyan.opacity(0.9)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.fan.isFanless ? "Passive" : "\(snapshot.fan.fanCount) fan\(snapshot.fan.fanCount == 1 ? "" : "s")")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(snapshot.fan.statusDescription)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func compactRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 { return "\(Int(bytesPerSec)) B/s" }
        if bytesPerSec < 1024 * 1024 { return String(format: "%.0f KB/s", bytesPerSec / 1024) }
        return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
    }

    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func thermalColor(_ state: ThermalStateLevel) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
}
