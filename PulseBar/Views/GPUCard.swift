import SwiftUI

public struct GPUCard: View {
    public let gpu: GPUSample

    public init(gpu: GPUSample) {
        self.gpu = gpu
    }

    public var body: some View {
        MetricCard(
            title: "GPU",
            icon: "display",
            iconColor: DesignTokens.accent,
            detailsText: "Model: \(gpu.modelName)" + (gpu.utilizationPercent.map { "\nUtilization: \(Formatters.formatPercentage($0, precision: 0))" } ?? "")
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(gpu.modelName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if let utilization = gpu.utilizationPercent {
                    Label(Formatters.formatPercentage(utilization, precision: 0), systemImage: "gauge.with.dots.needle.33percent")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Label("Utilization unavailable", systemImage: "minus.circle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
