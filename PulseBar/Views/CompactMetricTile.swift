import SwiftUI

/// Compact two-column dashboard tile on a glass platter.
public struct CompactMetricTile<Content: View>: View {
    public let title: String
    public let icon: String
    public let accent: Color
    @ViewBuilder public let content: () -> Content

    public init(
        title: String,
        icon: String,
        accent: Color = .accentColor,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                IconWell(systemName: icon, style: .badge(accent), size: 18)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }

            content()
        }
        .padding(DesignTokens.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassPlatter()
        // One VoiceOver group per tile, so columns aren't read interleaved.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// Large monospaced value that rolls when the number changes.
public struct LiveMetricValue: View {
    public let text: String
    public let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ text: String, size: CGFloat = 22) {
        self.text = text
        self.size = size
    }

    public var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .contentTransition(reduceMotion ? .opacity : .numericText())
            .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: text)
    }
}
