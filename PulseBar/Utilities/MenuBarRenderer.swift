import AppKit

public enum MenuBarMetricKind: String, CaseIterable, Equatable {
    case temperature
    case memory
    case cpu
    case network
    case battery
    case uptime

    var shortLabel: String {
        switch self {
        case .temperature: return "TEM"
        case .memory: return "MEM"
        case .cpu: return "CPU"
        case .network: return "NET"
        case .battery: return "BAT"
        case .uptime: return "UP"
        }
    }
}

@MainActor
public enum MenuBarRenderer {
    /// Compact metric column (~28–30 pt). Keep narrow so digits don't look oversized.
    public static let itemHeight: CGFloat = 18
    public static let itemWidth: CGFloat = 29

    public static func enabledKinds(settings: AppSettings, snapshot: SystemSnapshot) -> [MenuBarMetricKind] {
        var kinds: [MenuBarMetricKind] = []
        if settings.showMenuBarTemperature { kinds.append(.temperature) }
        if settings.showMenuBarMemory { kinds.append(.memory) }
        if settings.showMenuBarCPU { kinds.append(.cpu) }
        if settings.showMenuBarNetwork { kinds.append(.network) }
        if settings.showMenuBarBattery && snapshot.battery.isPresent { kinds.append(.battery) }
        if settings.showMenuBarUptime { kinds.append(.uptime) }
        return kinds
    }

    public static func signature(kind: MenuBarMetricKind, snapshot: SystemSnapshot, settings: AppSettings) -> String {
        "\(kind.rawValue)=\(displayValue(for: kind, snapshot: snapshot, settings: settings))"
    }

    public static func signature(snapshot: SystemSnapshot, settings: AppSettings) -> String {
        enabledKinds(settings: settings, snapshot: snapshot)
            .map { signature(kind: $0, snapshot: snapshot, settings: settings) }
            .joined(separator: "|")
    }

    public static func displayValue(for kind: MenuBarMetricKind, snapshot: SystemSnapshot, settings: AppSettings) -> String {
        switch kind {
        case .temperature:
            if let temp = snapshot.thermal.temperatureCelsius {
                // Menu bar: compact "74°" (unit letter omitted in the tiny cell).
                return Formatters.formatTemperatureMenuBar(temp, unit: settings.temperatureUnit)
            }
            return "—"
        case .memory:
            return Formatters.formatPercentage(snapshot.memory.usedPercentage, precision: 0)
        case .cpu:
            return Formatters.formatPercentage(snapshot.cpu.totalPercentage, precision: 0)
        case .network:
            return formatNetworkRate(snapshot.network.downloadBytesPerSec)
        case .battery:
            return "\(snapshot.battery.percentage)%"
        case .uptime:
            return Formatters.formatUptime(seconds: snapshot.uptime.uptimeSeconds)
        }
    }

    public static func accessibilityDescription(kind: MenuBarMetricKind, snapshot: SystemSnapshot, settings: AppSettings) -> String {
        "\(kind.shortLabel) \(displayValue(for: kind, snapshot: snapshot, settings: settings))"
    }

    private static func formatNetworkRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 { return "\(Int(bytesPerSec))B" }
        if bytesPerSec < 1024 * 1024 { return String(format: "%.0fK", bytesPerSec / 1024) }
        return String(format: "%.1fM", bytesPerSec / (1024 * 1024))
    }
}
