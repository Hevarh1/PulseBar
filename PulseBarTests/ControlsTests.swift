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

    func testPowerControllerChangingDurationKeepsAssertionActive() async throws {
        let controller = PowerController.shared
        controller.disableKeepAwake()
        defer { controller.disableKeepAwake() }

        controller.enableKeepAwakeFor(minutes: 30)
        try await Task.sleep(for: .milliseconds(50))
        controller.enableKeepAwakeFor(minutes: 60)
        let expectedEnd = try XCTUnwrap(controller.keepAwakeEndsAt)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(controller.isKeepAwakeActive)
        XCTAssertEqual(controller.keepAwakeEndsAt, expectedEnd)
    }

    func testPowerControllerSwitchingToUntilQuitCancelsExpiry() async throws {
        let controller = PowerController.shared
        controller.disableKeepAwake()
        defer { controller.disableKeepAwake() }

        controller.enableKeepAwake(until: Date().addingTimeInterval(0.2))
        try await Task.sleep(for: .milliseconds(50))
        controller.enableKeepAwake(until: nil)
        XCTAssertNil(controller.keepAwakeEndsAt)
        try await Task.sleep(for: .milliseconds(250))

        XCTAssertTrue(controller.isKeepAwakeActive)
        XCTAssertNil(controller.keepAwakeEndsAt)
    }

    func testPowerControllerTimedSessionExpires() async throws {
        let controller = PowerController.shared
        controller.disableKeepAwake()
        defer { controller.disableKeepAwake() }

        controller.enableKeepAwake(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(controller.isKeepAwakeActive)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertFalse(controller.isKeepAwakeActive)
        XCTAssertNil(controller.keepAwakeEndsAt)
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
