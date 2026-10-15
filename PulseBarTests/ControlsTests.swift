import XCTest
@testable import PulseBar

@MainActor
final class ControlsTests: XCTestCase {

    func testPowerControllerAssertionLifecycle() {
        let controller = PowerController.shared

        XCTAssertFalse(controller.isKeepAwakeActive)

        controller.enableKeepAwake(until: nil)
        XCTAssertTrue(controller.isKeepAwakeActive)

        controller.disableKeepAwake()
        XCTAssertFalse(controller.isKeepAwakeActive)
    }

    func testAppearanceControllerCanCheckAppearance() {
        let controller = AppearanceController.shared
        controller.checkCurrentAppearance()
        // Should execute cleanly without error
        XCTAssertNotNil(controller.isDarkMode)
    }

    func testMeetingModePreservesExistingKeepAwake() {
        let power = PowerController.shared
        let meeting = MeetingModeController.shared

        power.disableKeepAwake()
        meeting.deactivate()

        power.enableKeepAwake(until: nil)
        XCTAssertTrue(power.isKeepAwakeActive)

        meeting.activate()
        XCTAssertTrue(meeting.isActive)
        XCTAssertTrue(power.isKeepAwakeActive)

        meeting.deactivate()
        XCTAssertFalse(meeting.isActive)
        XCTAssertTrue(power.isKeepAwakeActive, "Meeting Mode should not disable pre-existing Keep Awake")

        power.disableKeepAwake()
    }

    func testMeetingModeReleasesOwnKeepAwake() {
        let power = PowerController.shared
        let meeting = MeetingModeController.shared

        power.disableKeepAwake()
        meeting.deactivate()
        XCTAssertFalse(power.isKeepAwakeActive)

        meeting.activate()
        XCTAssertTrue(power.isKeepAwakeActive)

        meeting.deactivate()
        XCTAssertFalse(power.isKeepAwakeActive)
    }
}
