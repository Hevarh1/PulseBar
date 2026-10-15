import AppKit

@MainActor
enum UtilityFeedback {
    static func playSuccess() {
        NSSound(named: "Pop")?.play()
    }

    static func showAppleScriptError(_ error: NSDictionary?, context: String) {
        let message = (error?[NSAppleScript.errorMessage] as? String)
            ?? "Automation was denied or failed. Grant PulseBar access in System Settings → Privacy & Security → Automation."
        let alert = NSAlert()
        alert.messageText = "\(context) Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    static func showInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
