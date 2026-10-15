import AppKit
import SwiftUI

/// The LIVE heartbeat: a dot that flashes once per sample, then dims.
///
/// Animated with Core Animation on its own layer, which the render server
/// runs without touching this process. A SwiftUI animation here would make
/// SwiftUI re-rasterize the whole dashboard on the CPU every frame.
struct PulseDot: NSViewRepresentable {
    let tick: UInt64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let restingOpacity: Float = 0.45

    func makeNSView(context: Context) -> NSView {
        let view = DotView()
        view.wantsLayer = true
        view.layer?.opacity = Self.restingOpacity
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard context.coordinator.lastTick != tick else { return }
        context.coordinator.lastTick = tick
        guard !reduceMotion else { return }
        let flash = CABasicAnimation(keyPath: "opacity")
        flash.fromValue = 1.0
        flash.toValue = Self.restingOpacity
        flash.duration = 0.75
        flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
        view.layer?.add(flash, forKey: "pulse")
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastTick: UInt64?
    }

    /// Accent-colored circle that follows accent and appearance changes.
    private final class DotView: NSView {
        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            layer?.cornerRadius = min(bounds.width, bounds.height) / 2
        }

        override func layout() {
            super.layout()
            needsDisplay = true
        }
    }
}
