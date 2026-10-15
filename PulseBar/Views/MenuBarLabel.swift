import SwiftUI

public struct MenuBarLabel: View {
    public let snapshot: SystemSnapshot
    @ObservedObject public var settings = AppSettings.shared

    public init(snapshot: SystemSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        HStack(spacing: 7) {
            if settings.showMenuBarTemperature {
                column(
                    value: snapshot.thermal.temperatureCelsius.map {
                        Formatters.formatTemperature($0, unit: settings.temperatureUnit)
                    } ?? "—",
                    label: "TEM"
                )
            }
            if settings.showMenuBarMemory {
                column(
                    value: Formatters.formatPercentage(snapshot.memory.usedPercentage, precision: 0),
                    label: "MEM"
                )
            }
            if settings.showMenuBarCPU {
                column(
                    value: Formatters.formatPercentage(snapshot.cpu.totalPercentage, precision: 0),
                    label: "CPU"
                )
            }
            if settings.showMenuBarNetwork {
                column(value: formatNetworkRate(snapshot.network.downloadBytesPerSec), label: "NET")
            }
            if settings.showMenuBarBattery && snapshot.battery.isPresent {
                column(value: "\(snapshot.battery.percentage)%", label: "BAT")
            }
            if settings.showMenuBarUptime {
                column(
                    value: Formatters.formatUptime(seconds: snapshot.uptime.uptimeSeconds),
                    label: "UP"
                )
            }
        }
    }

    private func column(value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 12, weight: .regular).monospacedDigit())
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func formatNetworkRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 { return "\(Int(bytesPerSec))B" }
        if bytesPerSec < 1024 * 1024 { return String(format: "%.0fK", bytesPerSec / 1024) }
        return String(format: "%.1fM", bytesPerSec / (1024 * 1024))
    }
}
