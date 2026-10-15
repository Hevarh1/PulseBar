import SwiftUI

public struct MetricCard<Content: View>: View {
    public let title: String
    public let icon: String
    public let iconColor: Color
    public let detailsText: String?
    @ViewBuilder public let content: () -> Content

    @State private var showingDetails: Bool = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        title: String,
        icon: String,
        iconColor: Color = Color(red: 0.35, green: 0.55, blue: 1.0),
        detailsText: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.detailsText = detailsText
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if let details = detailsText {
                    Button(action: { showingDetails.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingDetails) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(title) Details")
                                .font(.system(size: 12, weight: .bold))
                            Text(details)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(width: 220)
                    }
                }
            }

            content()
        }
        .padding(DesignTokens.cardPadding)
        .background(DesignTokens.cardBackground(reduceTransparency: reduceTransparency))
    }
}
