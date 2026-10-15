import AppKit

enum AppIcon {
    /// Bundled marketing icon (`.app` Resources, then SPM package resources).
    static var applicationImage: NSImage? {
        // Prefer the packaged .app Resources — never touch Bundle.module first;
        // SPM's accessor fatalErrors when PulseBar_PulseBar.bundle is missing.
        if let image = Bundle.main.image(forResource: "AppIcon") {
            return image
        }
        for ext in ["png", "icns"] {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: ext),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent("PulseBar_PulseBar.bundle")
            .appendingPathComponent("Contents/Resources/AppIcon.png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        // `swift run` / debug: load via SPM resource bundle.
        if Bundle.main.bundleURL.pathExtension != "app",
           let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
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
