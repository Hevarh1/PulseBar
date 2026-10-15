import AppKit
import Foundation

@MainActor
public enum SystemUtilitiesController {
    public static func copyLocalIPToClipboard() {
        let ip = NetworkReader().primaryLocalIPAddress() ?? "Unavailable"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
        UtilityFeedback.playSuccess()
    }

    public static func clearClipboard() {
        NSPasteboard.general.clearContents()
        UtilityFeedback.playSuccess()
    }

    public static func screenshotsFolderURL() -> URL {
        if let path = CFPreferencesCopyAppValue("location" as CFString, "com.apple.screencapture" as CFString) as? String {
            let expanded = (path as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    public static func openScreenshotsFolder() {
        NSWorkspace.shared.open(screenshotsFolderURL())
    }

    public static func ejectExternalVolumesWithConfirmation() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey, .volumeNameKey]
        guard let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) else { return }

        var external: [URL] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.volumeIsInternal == true { continue }
            if values.volumeIsRemovable == true || values.volumeIsEjectable == true {
                external.append(url)
            }
        }

        guard !external.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No External Volumes"
            alert.informativeText = "No removable volumes are currently mounted."
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Eject External Volumes?"
        alert.informativeText = "PulseBar will try to eject \(external.count) removable volume(s)."
        alert.addButton(withTitle: "Eject")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        for url in external {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                let err = NSAlert()
                err.messageText = "Eject Failed"
                err.informativeText = "\(url.lastPathComponent): \(error.localizedDescription)"
                err.runModal()
            }
        }
    }
}
