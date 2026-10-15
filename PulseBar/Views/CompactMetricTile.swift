import SwiftUI

/// Compact two-column dashboard tile.
public struct CompactMetricTile<Content: View>: View {
    public let title: String
    public let icon: String
    public let accent: Color
    @ViewBuilder public let content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        title: String,
        icon: String,
        accent: Color = Color(red: 0.30, green: 0.58, blue: 1.0),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accent)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }

            content()
        }
        .padding(DesignTokens.cardPadding)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.tileMinHeight, alignment: .topLeading)
        .background(DesignTokens.cardBackground(reduceTransparency: reduceTransparency))
    }
}

/// Large monospaced value that rolls when the number changes.
public struct LiveMetricValue: View {
    public let text: String
    public let size: CGFloat

    public init(_ text: String, size: CGFloat = 22) {
        self.text = text
        self.size = size
    }

    public var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.primary)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.35), value: text)
    }
}
