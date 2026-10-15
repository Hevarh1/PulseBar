import XCTest
import AppKit
import Carbon.HIToolbox
@testable import PulseBar

final class GlobalHotKeyTests: XCTestCase {
    /// An obscure combo so tests never collide with a running PulseBar's ⌃⌘P.
    private let testShortcut = GlobalHotKey.Shortcut(
        keyCode: UInt32(kVK_F18),
        modifiers: [.control, .option, .shift, .command],
        key: "F18"
    )

    @MainActor
    func testDashboardShortcutText() {
        let shortcut = DashboardShortcut.shortcut
        XCTAssertEqual(shortcut.displayString, "⌃⌘P")
        XCTAssertEqual(shortcut.spokenString, "Control Command P")
        XCTAssertEqual(shortcut.carbonModifiers, UInt32(controlKey | cmdKey))
        XCTAssertEqual(testShortcut.displayString, "⌃⌥⇧⌘F18")
    }

    @MainActor
    func testRegisteredHotKeyFiresAndAShortcutCanOnlyBeTakenOnce() throws {
        var presses = 0
        guard let hotKey = GlobalHotKey(testShortcut, onPress: { presses += 1 }) else {
            throw XCTSkip("Shortcut unavailable in this session")
        }
        // A second registration of the same keys is refused, as when another app owns them.
        XCTAssertNil(GlobalHotKey(testShortcut, onPress: {}))

        // Deliver a hot key event the way Carbon does for a real key press.
        // Our first registration in this process gets ID 1 or later; send IDs 1...16.
        for id in UInt32(1)...16 {
            sendHotKeyEvent(id: id)
        }
        XCTAssertEqual(presses, 1)

        hotKey.invalidate()
        // Released keys can be registered again.
        let again = GlobalHotKey(testShortcut, onPress: {})
        XCTAssertNotNil(again)
        again?.invalidate()
    }

    private func sendHotKeyEvent(id: UInt32) {
        var event: EventRef?
        guard CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, 0, &event) == noErr,
              let event else { return }
        var hotKeyID = EventHotKeyID(signature: 0x5042_4152, id: id)
        SetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            MemoryLayout<EventHotKeyID>.size,
            &hotKeyID
        )
        SendEventToEventTarget(event, GetApplicationEventTarget())
        ReleaseEvent(event)
    }
}
