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
            detailsText: "Model: \(gpu.modelName)\nUtilization and power metrics are not exposed through public macOS APIs on this Mac."
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(gpu.modelName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Label("Utilization unavailable", systemImage: "minus.circle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
