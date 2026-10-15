import SwiftUI

public struct MemoryCard: View {
    public let memory: MemorySample
    public let history: [Double]
    public let onFreeUp: () -> Void

    @State private var freedUpFeedback: Bool = false

    public init(memory: MemorySample, history: [Double], onFreeUp: @escaping () -> Void) {
        self.memory = memory
        self.history = history
        self.onFreeUp = onFreeUp
    }

    public var body: some View {
        MetricCard(
            title: "Memory",
            icon: "memorychip",
            iconColor: .purple,
            detailsText: "Total: \(Formatters.formatBytes(memory.totalBytes))\nUsed: \(Formatters.formatBytes(memory.usedBytes))\nFree: \(Formatters.formatBytes(memory.freeBytes))\nWired: \(Formatters.formatBytes(memory.wiredBytes))\nCompressed: \(Formatters.formatBytes(memory.compressedBytes))\nSwap Used: \(Formatters.formatBytes(memory.swapUsedBytes))"
        ) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Text("\(Formatters.formatBytes(memory.usedBytes)) / \(Formatters.formatBytes(memory.totalBytes))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        // Pressure badge
                        HStack(spacing: 3) {
                            Circle()
                                .fill(pressureColor)
                                .frame(width: 6, height: 6)
                            Text(memory.pressureLevel.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(pressureColor)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pressureColor.opacity(0.12))
                        .cornerRadius(4)
                    }

                    Spacer()

                    Text(Formatters.formatPercentage(memory.usedPercentage))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                GraphView(
                    dataPoints: history,
                    maxValue: 100.0,
                    strokeColor: .purple,
                    gradientColors: [.purple.opacity(0.35), .purple.opacity(0.0)],
                    height: 38
                )

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compressed: \(Formatters.formatBytes(memory.compressedBytes))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Wired: \(Formatters.formatBytes(memory.wiredBytes))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        onFreeUp()
                        freedUpFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            freedUpFeedback = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: freedUpFeedback ? "checkmark" : "arrow.triangle.2.circlepath")
                            Text(freedUpFeedback ? "Requested" : "Free Up")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pressureColor: Color {
        switch memory.pressureLevel {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
