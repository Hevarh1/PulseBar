import Foundation

private enum FinderDesktopPreferences {
    nonisolated static func readCreateDesktop() -> Bool {
        guard let value = CFPreferencesCopyAppValue("CreateDesktop" as CFString, "com.apple.finder" as CFString) else {
            return true
        }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let int = value as? Int { return int != 0 }
        return true
    }

    nonisolated static func writeCreateDesktop(_ createDesktop: Bool) {
        CFPreferencesSetValue(
            "CreateDesktop" as CFString,
            createDesktop ? kCFBooleanTrue : kCFBooleanFalse,
            "com.apple.finder" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesAppSynchronize("com.apple.finder" as CFString)
    }

    nonisolated static func restartFinder() {
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killTask.arguments = ["Finder"]
        try? killTask.run()
    }
}

@MainActor
public final class DesktopController: ObservableObject {
    public static let shared = DesktopController()

    @Published public private(set) var isDesktopIconsHidden: Bool = false

    private init() {
        isDesktopIconsHidden = !FinderDesktopPreferences.readCreateDesktop()
    }

    public func checkDesktopState() {
        isDesktopIconsHidden = !FinderDesktopPreferences.readCreateDesktop()
    }

    public func toggleDesktopIcons() {
        let hide = !isDesktopIconsHidden
        isDesktopIconsHidden = hide

        Task.detached(priority: .utility) {
            FinderDesktopPreferences.writeCreateDesktop(!hide)
            FinderDesktopPreferences.restartFinder()
        }
    }
}
