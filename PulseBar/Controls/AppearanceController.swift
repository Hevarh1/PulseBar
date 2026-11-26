import AppKit

@MainActor
public final class AppearanceController: ObservableObject {
    public static let shared = AppearanceController()

    @Published public private(set) var isDarkMode: Bool = false

    private init() {
        checkCurrentAppearance()
        // Fires for every system appearance change, including System Settings
        // and Control Center, so the toggle never goes stale.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppearanceController.shared.checkCurrentAppearance()
            }
        }
    }

    /// Reads the system setting, not this app's effective appearance, which
    /// lags behind a change and can be overridden per window.
    public func checkCurrentAppearance() {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        let style = global?["AppleInterfaceStyle"] as? String
        isDarkMode = style?.caseInsensitiveCompare("Dark") == .orderedSame
    }

    public func toggleDarkMode() {
        let target = !isDarkMode
        // Flip right away so the control responds; the notification confirms it.
        isDarkMode = target
        // Run after the click finishes: the script blocks while System Events
        // launches (and on first use while macOS asks for Automation access).
        DispatchQueue.main.async {
            let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(target)"
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            if let error {
                self.checkCurrentAppearance()
                UtilityFeedback.showAppleScriptError(error, context: "Dark Mode")
            }
        }
    }
}
