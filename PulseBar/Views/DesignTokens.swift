import SwiftUI

enum DesignTokens {
    static let popoverWidth: CGFloat = 408
    /// Fits header + six metric tiles + full utility grid without scrolling.
    static let popoverHeight: CGFloat = 820
    /// System accent — follows the user's accent color like Control Center.
    static let accent = Color.accentColor
    static let cardRadius: CGFloat = 22
    static let cardPadding: CGFloat = 12
    static let contentPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
    static let gridSpacing: CGFloat = 8
    /// Height of capsule controls (utility toggles); concentric with `iconWellSize`.
    static let controlHeight: CGFloat = 36
    static let iconWellSize: CGFloat = 26
    static let graphHeightCPU: CGFloat = 44
    static let graphHeightDefault: CGFloat = 32
    /// Concentric with the tile corner: `cardRadius - cardPadding`.
    static let graphRadius: CGFloat = 10
    static let headerHeight: CGFloat = 52

    /// Secondary text on glass. `.secondary` measures only 2.6–3.4:1 there;
    /// a vibrant 70% primary measures 7–11:1 on typical backdrops. Like
    /// Control Center, dark glass over a very bright wallpaper can still dip
    /// lower; Reduce Transparency switches to solid tiles.
    static var secondaryText: some ShapeStyle { HierarchicalShapeStyle.primary.opacity(0.7) }

    // Metric identity colors. System colors adapt to light/dark mode and
    // Increase Contrast.
    static let cpuUser = Color.blue
    static let cpuSystem = Color.red
    static let memory = Color.purple
    static let network = Color.green
    static let networkUp = Color.blue
    static let storage = Color.teal
    static let gpu = Color.orange
    static let fan = Color.cyan
}
