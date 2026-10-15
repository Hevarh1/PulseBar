import Foundation

public enum Formatters {
    public static func formatBytes(_ bytes: UInt64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useAll]
        byteCountFormatter.countStyle = .memory
        byteCountFormatter.includesUnit = true
        return byteCountFormatter.string(fromByteCount: Int64(bytes))
    }

    public static func formatDiskBytes(_ bytes: UInt64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useAll]
        byteCountFormatter.countStyle = .file
        byteCountFormatter.includesUnit = true
        return byteCountFormatter.string(fromByteCount: Int64(bytes))
    }

    public static func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return String(format: "%.0f B/s", bytesPerSec)
        } else if bytesPerSec < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        } else if bytesPerSec < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", bytesPerSec / (1024 * 1024 * 1024))
        }
    }

    public static func formatPercentage(_ value: Double, precision: Int = 1) -> String {
        let clamped = max(0.0, min(100.0, value))
        return String(format: "%.\(precision)f%%", clamped)
    }

    public static func formatTemperature(_ celsius: Double, unit: TemperatureUnit) -> String {
        switch unit {
        case .celsius:
            return String(format: "%.0f°C", celsius)
        case .fahrenheit:
            let f = celsius * 9.0 / 5.0 + 32.0
            return String(format: "%.0f°F", f)
        }
    }

    /// Compact menu-bar form (`74°`), not dashboard `74°C`.
    public static func formatTemperatureMenuBar(_ celsius: Double, unit: TemperatureUnit) -> String {
        switch unit {
        case .celsius:
            return String(format: "%.0f°", celsius)
        case .fahrenheit:
            let f = celsius * 9.0 / 5.0 + 32.0
            return String(format: "%.0f°", f)
        }
    }

    public static func formatUptime(seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

public enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case celsius = "Celsius (°C)"
    case fahrenheit = "Fahrenheit (°F)"

    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}
