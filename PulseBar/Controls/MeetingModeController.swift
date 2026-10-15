import Foundation

@MainActor
public final class MeetingModeController: ObservableObject {
    public static let shared = MeetingModeController()

    @Published public private(set) var isActive: Bool = false

    private var desktopWasHidden: Bool = false
    private var meetingEnabledKeepAwake: Bool = false

    private init() {}

    public func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    public func activate() {
        guard !isActive else { return }
        desktopWasHidden = DesktopController.shared.isDesktopIconsHidden
        if !desktopWasHidden {
            DesktopController.shared.toggleDesktopIcons()
        }
        if PowerController.shared.isKeepAwakeActive {
            meetingEnabledKeepAwake = false
        } else {
            PowerController.shared.enableKeepAwakeFor(minutes: 60)
            meetingEnabledKeepAwake = PowerController.shared.isKeepAwakeActive
        }
        isActive = true
    }

    public func deactivate() {
        guard isActive else { return }
        if meetingEnabledKeepAwake {
            PowerController.shared.disableKeepAwake()
        }
        meetingEnabledKeepAwake = false
        if !desktopWasHidden && DesktopController.shared.isDesktopIconsHidden {
            DesktopController.shared.toggleDesktopIcons()
        }
        isActive = false
    }
}
