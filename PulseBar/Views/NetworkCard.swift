import SwiftUI
import AppKit

public struct NetworkCard: View {
    public let network: NetworkSample
    public let downloadHistory: [Double]
    public let uploadHistory: [Double]
    public let graphMax: Double

    @State private var copiedIP: Bool = false

    public init(
        network: NetworkSample,
        downloadHistory: [Double],
        uploadHistory: [Double] = [],
        graphMax: Double = 102_400
    ) {
        self.network = network
        self.downloadHistory = downloadHistory
        self.uploadHistory = uploadHistory
        self.graphMax = graphMax
    }

    public var body: some View {
        MetricCard(
            title: "Network",
            icon: "network",
            iconColor: DesignTokens.accent,
            detailsText: "Interface: \(network.interfaceName)\nLocal IP: \(network.localIPAddress)\nDownload: \(Formatters.formatRate(network.downloadBytesPerSec))\nUpload: \(Formatters.formatRate(network.uploadBytesPerSec))"
        ) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(network.interfaceName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 12) {
                        rateLabel(icon: "arrow.down", value: network.downloadBytesPerSec, tint: DesignTokens.accent)
                        rateLabel(icon: "arrow.up", value: network.uploadBytesPerSec, tint: DesignTokens.accent.opacity(0.65))
                    }
                }

                ZStack {
                    GraphView(
                        dataPoints: downloadHistory,
                        maxValue: graphMax,
                        strokeColor: DesignTokens.accent,
                        gradientColors: [DesignTokens.accent.opacity(0.28), DesignTokens.accent.opacity(0.0)],
                        height: DesignTokens.graphHeightDefault
                    )
                    GraphView(
                        dataPoints: uploadHistory,
                        maxValue: graphMax,
                        strokeColor: DesignTokens.accent.opacity(0.55),
                        gradientColors: [.clear, .clear],
                        height: DesignTokens.graphHeightDefault
                    )
                }

                HStack {
                    Text("Local IP")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(network.localIPAddress)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(network.localIPAddress, forType: .string)
                        copiedIP = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            copiedIP = false
                        }
                    }) {
                        Image(systemName: copiedIP ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
    }

    private func rateLabel(icon: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(tint)
            Text(Formatters.formatRate(value))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}
