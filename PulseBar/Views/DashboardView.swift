import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject private var coordinator = MetricsCoordinator.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var shortcut = DashboardShortcut.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var memoryFreeRequested = false

    private enum Tile: CaseIterable {
        case cpu, memory, network, storage, gpu, fan
    }

    public init() {}

    public var body: some View {
        let snapshot = coordinator.currentSnapshot

        // No background of our own: on macOS 26+ the tiles float over the
        // desktop (DashboardPanel); on 14–15 they sit on the popover.
        GlassGroup {
            VStack(spacing: DesignTokens.sectionSpacing) {
                header(snapshot: snapshot)

                tileGrid(snapshot)

                if settings.showUtilityGrid {
                    UtilityGrid()
                }

                footer
            }
            .padding(DesignTokens.contentPadding)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: DesignTokens.popoverWidth)
        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: coordinator.sampleTick)
        .onChange(of: coordinator.sampleTick) { _, _ in
            guard !reduceMotion else { return }
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
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("PulseBar")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    liveBadge
                        .fixedSize()
                }
                HStack(spacing: 6) {
                    Text(snapshot.cpu.chipModel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(1)
                    if shortcut.isRegistered {
                        ShortcutKeycap(shortcut: DashboardShortcut.shortcut)
                            .help("Press \(DashboardShortcut.shortcut.displayString) anywhere to show or hide PulseBar")
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            statusItems(snapshot)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(height: DesignTokens.headerHeight)
        .glassSurface(in: Capsule())
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(DesignTokens.accent)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 1.0 : 0.45)
                .scaleEffect(pulse ? 1.2 : 1.0)
            Text("LIVE")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(DesignTokens.accent.opacity(0.18), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live")
    }

    /// Temperature, battery and uptime.
    private func statusItems(_ snapshot: SystemSnapshot) -> some View {
        HStack(spacing: 10) {
            if let temp = snapshot.thermal.temperatureCelsius {
                let text = Formatters.formatTemperature(temp, unit: settings.temperatureUnit)
                statusItem(
                    icon: thermometerSymbol(snapshot.thermal.thermalState),
                    text: text,
                    tint: AnyShapeStyle(thermalColor(snapshot.thermal.thermalState)),
                    label: "Temperature",
                    spokenValue: "\(text), \(snapshot.thermal.thermalState.rawValue)",
                    paletteLevel: true
                )
            }

            if snapshot.battery.isPresent {
                statusItem(
                    icon: batterySymbol(snapshot.battery),
                    text: "\(snapshot.battery.percentage)%",
                    tint: snapshot.battery.percentage < 20
                        ? AnyShapeStyle(Color.red)
                        : AnyShapeStyle(DesignTokens.secondaryText),
                    label: "Battery"
                )
            }

            statusItem(
                icon: "clock",
                text: Formatters.formatUptime(seconds: snapshot.uptime.uptimeSeconds),
                tint: AnyShapeStyle(DesignTokens.secondaryText),
                label: "Uptime"
            )
        }
    }

    private func statusItem(
        icon: String,
        text: String,
        tint: AnyShapeStyle,
        label: String,
        spokenValue: String? = nil,
        paletteLevel: Bool = false
    ) -> some View {
        HStack(spacing: 4) {
            Group {
                if paletteLevel {
                    // The level stays legible; the outline carries the state color.
                    Image(systemName: icon)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(DesignTokens.secondaryText, tint)
                } else {
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                }
            }
            .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.secondaryText)
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: text)
        }
        // SwiftUI drops accessibilityValue on a trait-less element, so the
        // value goes in the label.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(spokenValue ?? text)")
    }

    private var footer: some View {
        HStack {
            Button {
                SettingsWindowController.shared.showPreferences()
            } label: {
                footerLabel("Settings", systemImage: "gearshape")
            }

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                footerLabel("Quit", systemImage: "power")
            }
        }
        .buttonStyle(GlassCapsuleButtonStyle())
    }

    private func footerLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 12)
            .frame(height: 28)
    }

    // MARK: - Tiles

    private var visibleTiles: [Tile] {
        Tile.allCases.filter { tile in
            switch tile {
            case .cpu: return settings.showCPUCard
            case .memory: return settings.showMemoryCard
            case .network: return settings.showNetworkCard
            case .storage: return settings.showStorageCard
            case .gpu: return settings.showGPUCard
            case .fan: return settings.showFanCard
            }
        }
    }

    /// Two-column tile grid. An eager `Grid` (not `LazyVGrid`) gives the
    /// popover an exact fitted height and lets tiles in a row share one height.
    private func tileGrid(_ snapshot: SystemSnapshot) -> some View {
        let tiles = visibleTiles
        return Grid(horizontalSpacing: DesignTokens.gridSpacing, verticalSpacing: DesignTokens.gridSpacing) {
            ForEach(Array(stride(from: 0, to: tiles.count, by: 2)), id: \.self) { start in
                GridRow {
                    tile(tiles[start], snapshot)
                    if start + 1 < tiles.count {
                        tile(tiles[start + 1], snapshot)
                    } else {
                        // Takes its column share so a lone tile stays half width.
                        Color.clear.gridCellUnsizedAxes(.vertical)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ tile: Tile, _ snapshot: SystemSnapshot) -> some View {
        switch tile {
        case .cpu: cpuTile(snapshot)
        case .memory: memoryTile(snapshot)
        case .network: networkTile(snapshot)
        case .storage: storageTile(snapshot)
        case .gpu: gpuTile(snapshot)
        case .fan: fanTile(snapshot)
        }
    }

    private func cpuTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "CPU", icon: "cpu", accent: DesignTokens.cpuUser) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    LiveMetricValue(Formatters.formatPercentage(snapshot.cpu.totalPercentage, precision: 0))
                    Spacer(minLength: 0)
                    Text("\(snapshot.cpu.coreCount)c")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .accessibilityLabel("\(snapshot.cpu.coreCount) cores")
                }

                CPUStackedGraphView(
                    userPoints: snapshot.cpuUserHistory,
                    sysPoints: snapshot.cpuSystemHistory,
                    height: DesignTokens.graphHeightCPU
                )
                .graphWell()

                HStack {
                    legendDot(
                        DesignTokens.cpuUser,
                        "Usr \(Int(snapshot.cpu.userPercentage))%",
                        spoken: "User \(Int(snapshot.cpu.userPercentage)) percent"
                    )
                    Spacer(minLength: 4)
                    legendDot(
                        DesignTokens.cpuSystem,
                        "Sys \(Int(snapshot.cpu.systemPercentage))%",
                        spoken: "System \(Int(snapshot.cpu.systemPercentage)) percent"
                    )
                }
            }
        }
    }

    private func memoryTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "Memory", icon: "memorychip", accent: DesignTokens.memory) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    LiveMetricValue(Formatters.formatPercentage(snapshot.memory.usedPercentage, precision: 0))
                    Spacer(minLength: 0)
                    // The dot carries the color; the text stays readable on any glass.
                    HStack(spacing: 4) {
                        Circle()
                            .fill(pressureColor(snapshot.memory.pressureLevel))
                            .frame(width: 6, height: 6)
                        Text(snapshot.memory.pressureLevel.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                }

                GraphView(
                    dataPoints: snapshot.memoryHistory,
                    maxValue: 100,
                    strokeColor: DesignTokens.memory,
                    gradientColors: [DesignTokens.memory.opacity(0.35), DesignTokens.memory.opacity(0)],
                    height: DesignTokens.graphHeightDefault,
                    accessibilityName: "Memory history",
                    accessibilityValueText: "\(Int(snapshot.memoryHistory.last ?? 0)) percent"
                )
                .graphWell()

                HStack {
                    Text("\(Formatters.formatBytes(snapshot.memory.usedBytes)) / \(Formatters.formatBytes(snapshot.memory.totalBytes))")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.secondaryText)
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
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(memoryFreeRequested)
                    .accessibilityLabel(memoryFreeRequested ? "Memory release requested" : "Free up memory")
                }
            }
        }
    }

    private func networkTile(_ snapshot: SystemSnapshot) -> some View {
        let down = compactRate(snapshot.network.downloadBytesPerSec)
        let up = compactRate(snapshot.network.uploadBytesPerSec)
        return CompactMetricTile(title: "Network", icon: "network", accent: DesignTokens.network) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("↓")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DesignTokens.secondaryText)
                        LiveMetricValue(down, size: 16)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Download \(down)")
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("↑")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DesignTokens.secondaryText)
                        LiveMetricValue(up, size: 16)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Upload \(up)")
                }

                ZStack {
                    GraphView(
                        dataPoints: snapshot.networkDownHistory,
                        maxValue: coordinator.networkGraphMaxBytesPerSec,
                        strokeColor: DesignTokens.network,
                        gradientColors: [DesignTokens.network.opacity(0.3), .clear],
                        height: DesignTokens.graphHeightDefault
                    )
                    GraphView(
                        dataPoints: snapshot.networkUpHistory,
                        maxValue: coordinator.networkGraphMaxBytesPerSec,
                        strokeColor: DesignTokens.networkUp.opacity(0.8),
                        gradientColors: [.clear, .clear],
                        height: DesignTokens.graphHeightDefault
                    )
                }
                .graphWell()
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel("Network history")
                .accessibilityValue("download \(down), upload \(up)")

                Text(snapshot.network.localIPAddress)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private func storageTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "Storage", icon: "internaldrive", accent: DesignTokens.storage) {
            VStack(alignment: .leading, spacing: 8) {
                LiveMetricValue(Formatters.formatPercentage(snapshot.disk.usedPercentage, precision: 0))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(DesignTokens.storage)
                            .frame(width: geo.size.width * CGFloat(min(1, max(0, snapshot.disk.usedPercentage / 100))))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: snapshot.disk.usedPercentage)
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)

                Text("\(Formatters.formatDiskBytes(snapshot.disk.freeBytes)) free")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)

                HStack {
                    Text("↓ \(compactRate(snapshot.disk.readBytesPerSec))")
                        .accessibilityLabel("Read \(compactRate(snapshot.disk.readBytesPerSec))")
                    Spacer()
                    Text("↑ \(compactRate(snapshot.disk.writeBytesPerSec))")
                        .accessibilityLabel("Write \(compactRate(snapshot.disk.writeBytesPerSec))")
                }
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(DesignTokens.secondaryText)
                .monospacedDigit()
            }
        }
    }

    private func gpuTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "GPU", icon: "display", accent: DesignTokens.gpu) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.gpu.modelName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Utilization unavailable")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
    }

    private func fanTile(_ snapshot: SystemSnapshot) -> some View {
        CompactMetricTile(title: "Fan", icon: snapshot.fan.isFanless ? "fan.slash" : "fan", accent: DesignTokens.fan) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.fan.isFanless ? "Passive" : "\(snapshot.fan.fanCount) fan\(snapshot.fan.fanCount == 1 ? "" : "s")")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(snapshot.fan.statusDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(3)
            }
        }
    }

    private func legendDot(_ color: Color, _ text: String, spoken: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private func compactRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 { return "\(Int(bytesPerSec)) B/s" }
        if bytesPerSec < 1024 * 1024 { return String(format: "%.0f KB/s", bytesPerSec / 1024) }
        return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
    }

    private func batterySymbol(_ battery: BatterySample) -> String {
        if battery.isCharging { return "battery.100.bolt" }
        switch battery.percentage {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    /// The glyph itself shows the thermal state, not only its color.
    private func thermometerSymbol(_ state: ThermalStateLevel) -> String {
        switch state {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious, .critical: return "thermometer.high"
        }
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
