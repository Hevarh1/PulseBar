import AppKit

@MainActor
public final class ScreenController {
    public static let shared = ScreenController()

    private init() {}

    public func lockScreen() {
        // Use loginwindow SACLockScreenImmediate via dlopen/dlsym if available, or AppleScript Ctrl+Cmd+Q
        typealias SACLockScreenImmediateType = @convention(c) () -> Void
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY) {
            defer { dlclose(handle) }
            if let sym = dlsym(handle, "SACLockScreenImmediate") {
                let lockFunc = unsafeBitCast(sym, to: SACLockScreenImmediateType.self)
                lockFunc()
                return
            }
        }

        // Fallback: CGSession lock (same path as the login menu lock)
        let cgSession = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        let task = Process()
        task.executableURL = cgSession
        task.arguments = ["-suspend"]
        do {
            try task.run()
        } catch {
            let script = "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            if let error {
                UtilityFeedback.showAppleScriptError(error, context: "Lock Screen")
            }
        }
    }

    public func startScreenSaver() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "/System/Library/CoreServices/ScreenSaverEngine.app"]
        try? task.run()
    }
}
