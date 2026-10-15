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

    /// The icon pre-rendered once at 28pt (2x pixels) for the dashboard header.
    /// The 1024px source is decoded a single time and not kept; reading
    /// `applicationImage` on every refresh re-decoded and rescaled it each second.
    static let dashboardIcon: NSImage? = applicationImage.map { rendered($0, points: 28) }

    private static func rendered(_ source: NSImage, points: CGFloat) -> NSImage {
        let pixels = Int(points * 2)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return source }
        rep.size = NSSize(width: points, height: points)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: points, height: points))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
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
