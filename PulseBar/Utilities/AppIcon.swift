import AppKit

enum AppIcon {
    /// Bundled marketing / Dock icon when packaged as `.app`.
    static var applicationImage: NSImage? {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(named: "AppIcon")
    }

    /// Template menu-bar glyph (adapts to light/dark menu bar).
    static func menuBarTemplateImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let image = NSImage(
            systemSymbolName: "gauge.with.dots.needle.67percent",
            accessibilityDescription: "PulseBar"
        )?.withSymbolConfiguration(config) {
            image.isTemplate = true
            return image
        }
        // Fallback if the symbol is unavailable on older OSes.
        let fallback = NSImage(
            systemSymbolName: "chart.bar.fill",
            accessibilityDescription: "PulseBar"
        ) ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }
}
