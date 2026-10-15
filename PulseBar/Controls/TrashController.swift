import AppKit

@MainActor
public final class TrashController {
    public static let shared = TrashController()

    private init() {}

    public func emptyTrashWithConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Empty Trash?"
        alert.informativeText = "Are you sure you want to permanently erase the items in the Trash? You can’t undo this action."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Empty Trash")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            emptyTrash()
        }
    }

    private func emptyTrash() {
        let script = "tell application \"Finder\" to empty trash"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                UtilityFeedback.showAppleScriptError(error, context: "Empty Trash")
            }
        }
    }
}
