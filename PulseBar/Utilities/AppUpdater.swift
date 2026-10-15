import AppKit
import Foundation

/// Checks GitHub Releases and can download + replace the installed `.app`.
@MainActor
public final class AppUpdater: ObservableObject {
    public static let shared = AppUpdater()

    public enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateInfo)
        case downloading(Double)
        case installing
        case failed(String)
    }

    public struct UpdateInfo: Equatable {
        public let version: String
        public let tagName: String
        public let releaseNotes: String
        public let downloadURL: URL
        public let releasePageURL: URL
    }

    private static let releasesAPI = URL(string: "https://api.github.com/repos/Hevarh1/PulseBar/releases/latest")!
    private static let skippedVersionKey = "skippedUpdateVersion"
    private static let lastCheckKey = "lastUpdateCheckAt"
    private static let zipAssetName = "PulseBar.app.zip"
    private static let minimumCheckInterval: TimeInterval = 60 * 60 * 6

    @Published public private(set) var status: Status = .idle

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60 * 10
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "User-Agent": "PulseBar-Updater"
        ]
        return URLSession(configuration: config)
    }()

    private init() {}

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Automatic background check shortly after launch (respects prefs + throttle).
    public func scheduleAutomaticCheckIfNeeded() {
        guard AppSettings.shared.checkForUpdatesAutomatically else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        if let last, Date().timeIntervalSince(last) < Self.minimumCheckInterval {
            return
        }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await checkForUpdates(interactive: false)
        }
    }

    public func checkForUpdates(interactive: Bool) async {
        if case .downloading = status { return }
        if case .installing = status { return }

        status = .checking
        do {
            let info = try await fetchLatestUpdate()
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)

            guard Version.compare(info.version, currentVersion) == .orderedDescending else {
                status = .upToDate
                if interactive {
                    presentAlert(
                        title: "You’re up to date",
                        message: "PulseBar \(currentVersion) is the latest release."
                    )
                }
                return
            }

            let skipped = UserDefaults.standard.string(forKey: Self.skippedVersionKey)
            if !interactive, skipped == info.version {
                status = .available(info)
                return
            }

            status = .available(info)
            if interactive || skipped != info.version {
                presentUpdateAvailable(info, interactive: interactive)
            }
        } catch {
            let message = error.localizedDescription
            status = .failed(message)
            if interactive {
                presentAlert(title: "Update Check Failed", message: message)
            }
        }
    }

    public func installUpdate(_ info: UpdateInfo) {
        guard installedAppURL() != nil else {
            presentAlert(
                title: "Can’t Install Update",
                message: "Updates only work from an installed PulseBar.app (not `swift run`). Download the release and replace the app once, then in-app updates will work."
            )
            return
        }

        Task { await downloadAndInstall(info) }
    }

    public func skipVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: Self.skippedVersionKey)
        status = .idle
    }

    public func openReleasePage(_ info: UpdateInfo) {
        NSWorkspace.shared.open(info.releasePageURL)
    }

    // MARK: - Network

    private func fetchLatestUpdate() async throws -> UpdateInfo {
        var request = URLRequest(url: Self.releasesAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let version = Version.normalize(release.tagName)
        guard let asset = release.assets.first(where: { $0.name == Self.zipAssetName })
                ?? release.assets.first(where: { $0.name.hasSuffix(".zip") }),
              let downloadURL = URL(string: asset.browserDownloadURL) else {
            throw UpdateError.missingAsset
        }
        guard let pageURL = URL(string: release.htmlURL) else {
            throw UpdateError.badReleaseURL
        }

        return UpdateInfo(
            version: version,
            tagName: release.tagName,
            releaseNotes: Self.stripMarkdown(release.body ?? ""),
            downloadURL: downloadURL,
            releasePageURL: pageURL
        )
    }

    private func downloadAndInstall(_ info: UpdateInfo) async {
        status = .downloading(0)

        do {
            status = .downloading(0.05)
            let zipURL = try await download(from: info.downloadURL)
            status = .downloading(1)

            status = .installing
            let extractedApp = try extractApp(from: zipURL)
            try stageReplacement(newApp: extractedApp)
            UserDefaults.standard.set(nil, forKey: Self.skippedVersionKey)
            // Replacement script relaunches after we quit.
            NSApp.terminate(nil)
        } catch {
            status = .failed(error.localizedDescription)
            presentAlert(title: "Update Failed", message: error.localizedDescription)
        }
    }

    private func download(from url: URL) async throws -> URL {
        let (tempURL, response) = try await session.download(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseBar-update-\(UUID().uuidString).zip")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    private func extractApp(from zipURL: URL) throws -> URL {
        let fm = FileManager.default
        let extractDir = fm.temporaryDirectory.appendingPathComponent("PulseBar-extract-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-x", "-k", zipURL.path, extractDir.path]
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw UpdateError.extractFailed
        }

        if let direct = Optional(extractDir.appendingPathComponent("PulseBar.app")),
           fm.fileExists(atPath: direct.path) {
            return direct
        }

        let kids = try fm.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
        if let app = kids.first(where: { $0.pathExtension == "app" }) {
            return app
        }
        throw UpdateError.extractFailed
    }

    private func installedAppURL() -> URL? {
        let url = Bundle.main.bundleURL
        // Packaged app, or Contents/MacOS → …/PulseBar.app
        if url.pathExtension == "app" { return url }
        if url.lastPathComponent == "MacOS",
           url.deletingLastPathComponent().deletingLastPathComponent().pathExtension == "app" {
            return url.deletingLastPathComponent().deletingLastPathComponent()
        }
        return nil
    }

    private func stageReplacement(newApp: URL) throws {
        guard let destination = installedAppURL() else {
            throw UpdateError.notBundledApp
        }

        let fm = FileManager.default
        let scriptURL = fm.temporaryDirectory.appendingPathComponent("pulsebar-update-\(UUID().uuidString).sh")
        let pid = ProcessInfo.processInfo.processIdentifier

        let script = """
        #!/bin/bash
        set -euo pipefail
        PID="\(pid)"
        SRC=\(shellEscape(newApp.path))
        DST=\(shellEscape(destination.path))
        while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
        sleep 0.4
        rm -rf "$DST"
        /usr/bin/ditto "$SRC" "$DST"
        /usr/bin/xattr -cr "$DST" 2>/dev/null || true
        /usr/bin/open "$DST"
        rm -f -- "$0"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
    }

    // MARK: - UI

    private func presentUpdateAvailable(_ info: UpdateInfo, interactive: Bool) {
        let alert = NSAlert()
        alert.messageText = "PulseBar \(info.version) is available"
        let notes = info.releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = notes.isEmpty
            ? "You have \(currentVersion). Install the update to get the latest changes."
            : "You have \(currentVersion).\n\n\(notes)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        if !interactive {
            alert.addButton(withTitle: "Skip This Version")
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            installUpdate(info)
        case .alertThirdButtonReturn:
            skipVersion(info.version)
        default:
            break
        }
    }

    private func presentAlert(title: String, message: String) {
        UtilityFeedback.showInfo(title: title, message: message)
    }

    private static func stripMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - Version helpers

enum Version {
    static func normalize(_ tagOrVersion: String) -> String {
        var s = tagOrVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("v") {
            s.removeFirst()
        }
        return s
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = components(normalize(lhs))
        let b = components(normalize(rhs))
        let count = max(a.count, b.count)
        for i in 0..<count {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { part in
            let digits = part.prefix(while: { $0.isNumber })
            return Int(digits) ?? 0
        }
    }
}

// MARK: - GitHub models

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let body: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private enum UpdateError: LocalizedError {
    case httpStatus(Int)
    case missingAsset
    case badReleaseURL
    case downloadFailed
    case extractFailed
    case notBundledApp

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code): return "GitHub returned HTTP \(code)."
        case .missingAsset: return "The latest release has no PulseBar.app.zip asset."
        case .badReleaseURL: return "Invalid release page URL."
        case .downloadFailed: return "The download failed."
        case .extractFailed: return "Couldn’t unpack the update archive."
        case .notBundledApp: return "PulseBar isn’t running from an installed .app."
        }
    }
}
