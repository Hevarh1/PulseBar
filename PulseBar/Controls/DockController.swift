import Foundation

private enum DockPreferences {
    nonisolated static func readAutohide() -> Bool {
        guard let value = CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) else {
            return false
        }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let int = value as? Int { return int != 0 }
        return false
    }

    nonisolated static func writeAutohide(_ hidden: Bool) {
        CFPreferencesSetValue(
            "autohide" as CFString,
            hidden ? kCFBooleanTrue : kCFBooleanFalse,
            "com.apple.dock" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
    }

    nonisolated static func restartDock() {
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killTask.arguments = ["Dock"]
        try? killTask.run()
    }
}

@MainActor
public final class DockController: ObservableObject {
    public static let shared = DockController()

    @Published public private(set) var isDockHidden: Bool = false

    private init() {
        isDockHidden = DockPreferences.readAutohide()
    }

    public func checkDockState() {
        isDockHidden = DockPreferences.readAutohide()
    }

    public func toggleDockAutoHide() {
        let newState = !isDockHidden
        isDockHidden = newState

        Task.detached(priority: .utility) {
            DockPreferences.writeAutohide(newState)
            DockPreferences.restartDock()
        }
    }
}
