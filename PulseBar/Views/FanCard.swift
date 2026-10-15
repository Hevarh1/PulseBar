import SwiftUI

public struct FanCard: View {
    public let fan: FanSample

    public init(fan: FanSample) {
        self.fan = fan
    }

    public var body: some View {
        MetricCard(
            title: "Fan",
            icon: fan.isFanless ? "fan.slash" : "fan",
            iconColor: DesignTokens.accent,
            detailsText: fan.isFanless
                ? "This Mac uses passive cooling — no mechanical fans."
                : "Fans detected: \(fan.fanCount). RPM is not available without private IOKit interfaces."
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(fan.statusDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                if fan.isFanless {
                    Label("Passive cooling", systemImage: "leaf")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                } else if fan.fanSpeeds.isEmpty {
                    Label("RPM unavailable", systemImage: "minus.circle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
