import AppKit

@MainActor
public final class AppearanceController: ObservableObject {
    public static let shared = AppearanceController()

    @Published public private(set) var isDarkMode: Bool = false

    private init() {
        checkCurrentAppearance()
    }

    public func checkCurrentAppearance() {
        let appearance = NSApplication.shared.effectiveAppearance
        isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    public func toggleDarkMode() {
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error {
                UtilityFeedback.showAppleScriptError(error, context: "Dark Mode")
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.checkCurrentAppearance()
                }
            }
        }
    }
}
