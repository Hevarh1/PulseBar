import XCTest
import AppKit
import SwiftUI
@testable import PulseBar

final class DashboardPanelTests: XCTestCase {
    @MainActor
    func testShowAndDismissLifecycle() throws {
        guard NSScreen.main != nil else { throw XCTSkip("Needs a window server") }

        let anchorWindow = NSWindow(
            contentRect: NSRect(x: 200, y: 600, width: 120, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let anchor = NSView(frame: NSRect(x: 40, y: 10, width: 30, height: 20))
        anchorWindow.contentView?.addSubview(anchor)

        let panel = DashboardPanel()
        var closeCount = 0
        panel.onClose = { closeCount += 1 }

        panel.show(below: anchor, content: Text("Dashboard").frame(width: 200, height: 100))
        XCTAssertTrue(panel.isShown)
        XCTAssertTrue(panel.isVisible)
        // Hangs below the anchor, centered on it.
        let anchorRect = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        XCTAssertEqual(panel.frame.maxY, anchorRect.minY, accuracy: 0.5)

        panel.cancelOperation(nil) // Esc
        XCTAssertFalse(panel.isShown)
        XCTAssertEqual(closeCount, 1)

        panel.dismiss() // already closed: no second callback
        XCTAssertEqual(closeCount, 1)

        // After the fade-out the hidden dashboard is released, so it stops
        // re-rendering on every sample.
        let until = Date().addingTimeInterval(0.6)
        while Date() < until {
            RunLoop.main.run(mode: .default, before: min(until, Date().addingTimeInterval(0.02)))
        }
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(panel.contentView)
    }
}
