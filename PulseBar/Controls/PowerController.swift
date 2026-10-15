import Foundation
import IOKit.pwr_mgt

@MainActor
public final class PowerController: ObservableObject {
    public static let shared = PowerController()

    @Published public private(set) var isKeepAwakeActive: Bool = false
    @Published public private(set) var keepAwakeEndsAt: Date?
    nonisolated(unsafe) private var assertionID: IOPMAssertionID = 0
    private var timerTask: Task<Void, Never>?

    private init() {}

    public func toggleKeepAwake() {
        if isKeepAwakeActive {
            disableKeepAwake()
        } else {
            enableKeepAwake(until: nil)
        }
    }

    public func enableKeepAwake(until endDate: Date?) {
        guard !isKeepAwakeActive else { return }

        let reason = "PulseBar Keep Awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isKeepAwakeActive = true
            keepAwakeEndsAt = endDate
            scheduleTimerIfNeeded(endDate: endDate)
        } else {
            UtilityFeedback.showInfo(
                title: "Keep Awake Unavailable",
                message: "Could not create a power assertion (error \(result)). Display sleep may still occur."
            )
        }
    }

    public func enableKeepAwakeFor(minutes: Int) {
        if isKeepAwakeActive {
            disableKeepAwake()
        }
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        enableKeepAwake(until: end)
    }

    public func disableKeepAwake() {
        timerTask?.cancel()
        timerTask = nil
        keepAwakeEndsAt = nil
        guard isKeepAwakeActive else { return }
        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            isKeepAwakeActive = false
            assertionID = 0
        }
    }

    private func scheduleTimerIfNeeded(endDate: Date?) {
        timerTask?.cancel()
        guard let endDate else { return }
        timerTask = Task { [weak self] in
            let delay = endDate.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            await self?.disableKeepAwake()
        }
    }

    deinit {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }
}
