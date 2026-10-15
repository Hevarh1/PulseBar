import SwiftUI

enum DesignTokens {
    static let popoverWidth: CGFloat = 408
    /// Fits header + six metric tiles + full utility grid without scrolling.
    static let popoverHeight: CGFloat = 820
    static let accent = Color(red: 0.30, green: 0.58, blue: 1.0)
    static let cardRadius: CGFloat = 12
    static let cardPadding: CGFloat = 10
    static let sectionSpacing: CGFloat = 8
    static let gridSpacing: CGFloat = 8
    static let graphHeightCPU: CGFloat = 44
    static let graphHeightDefault: CGFloat = 32
    static let tileMinHeight: CGFloat = 118

    static func cardBackground(reduceTransparency: Bool) -> some View {
        Group {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            }
        }
    }
}
