import SwiftUI

public struct CPUCard: View {
    public let cpu: CPUSample
    public let userHistory: [Double]
    public let systemHistory: [Double]
    public let temperatureCelsius: Double?
    public let temperatureUnit: TemperatureUnit

    public init(
        cpu: CPUSample,
        userHistory: [Double] = [],
        systemHistory: [Double] = [],
        temperatureCelsius: Double? = nil,
        temperatureUnit: TemperatureUnit = .celsius
    ) {
        self.cpu = cpu
        self.userHistory = userHistory
        self.systemHistory = systemHistory
        self.temperatureCelsius = temperatureCelsius
        self.temperatureUnit = temperatureUnit
    }

    public var body: some View {
        MetricCard(
            title: "CPU",
            icon: "cpu",
            iconColor: DesignTokens.accent,
            detailsText: "Model: \(cpu.chipModel)\nCores: \(cpu.coreCount)\nUser: \(Formatters.formatPercentage(cpu.userPercentage))\nSystem: \(Formatters.formatPercentage(cpu.systemPercentage))\nIdle: \(Formatters.formatPercentage(cpu.idlePercentage))"
        ) {
            VStack(spacing: 10) {
                // Header: Chip model on left, temperature (or total %) on right in blue
                HStack(alignment: .firstTextBaseline) {
                    Text(cpu.chipModel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    if let temp = temperatureCelsius {
                        Text(Formatters.formatTemperature(temp, unit: temperatureUnit))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignTokens.accent)
                    } else {
                        Text(Formatters.formatPercentage(cpu.totalPercentage))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignTokens.accent)
                    }
                }

                // Stacked Area Chart (User in Blue, System in Red, Idle above)
                CPUStackedGraphView(
                    userPoints: userHistory,
                    sysPoints: systemHistory,
                    height: DesignTokens.graphHeightCPU
                )
                .graphWell()

                // Detailed Legend
                VStack(spacing: 6) {
                    HStack {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(red: 0.20, green: 0.60, blue: 1.0))
                                .frame(width: 12, height: 12)
                            Text("User")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Text(Formatters.formatPercentage(cpu.userPercentage, precision: 0))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    HStack {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(red: 0.95, green: 0.30, blue: 0.30))
                                .frame(width: 12, height: 12)
                            Text("System")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Text(Formatters.formatPercentage(cpu.systemPercentage, precision: 0))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    HStack {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 12, height: 12)
                            Text("Idle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(Formatters.formatPercentage(cpu.idlePercentage, precision: 0))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}
