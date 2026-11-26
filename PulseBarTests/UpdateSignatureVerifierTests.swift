import XCTest
@testable import PulseBar

final class UpdateSignatureVerifierTests: XCTestCase {
    func testRequirementCompiles() throws {
        var requirement: SecRequirement?
        XCTAssertEqual(
            SecRequirementCreateWithString(UpdateSignatureVerifier.developerIDRequirement as CFString, [], &requirement),
            errSecSuccess
        )
    }

    func testRejectsAppleSignedAppWithOtherIdentity() throws {
        // Validly signed, but by Apple and with another bundle identifier.
        let calculator = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        guard FileManager.default.fileExists(atPath: calculator.path) else { throw XCTSkip("No Calculator.app") }
        XCTAssertThrowsError(try UpdateSignatureVerifier.verify(appAt: calculator))
    }

    func testAcceptsWhenRequirementMatches() throws {
        // Same checking path, with a requirement Calculator does satisfy.
        let calculator = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        guard FileManager.default.fileExists(atPath: calculator.path) else { throw XCTSkip("No Calculator.app") }
        XCTAssertNoThrow(try UpdateSignatureVerifier.verify(
            appAt: calculator,
            requirement: #"anchor apple and identifier "com.apple.calculator""#
        ))
    }

    func testRejectsUnsignedFolder() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotAnApp-\(UUID().uuidString).app", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertThrowsError(try UpdateSignatureVerifier.verify(appAt: dir))
    }

    /// Local-only: PB_SIGTEST points at signed copies made with the real
    /// Developer ID (Good), the same copy edited after signing (Tampered), and
    /// one signed with a different certificate (Other).
    func testRealDeveloperIDBuilds() throws {
        guard let root = ProcessInfo.processInfo.environment["PB_SIGTEST"] else {
            throw XCTSkip("Set PB_SIGTEST to run against signed test builds")
        }
        let base = URL(fileURLWithPath: root)
        XCTAssertNoThrow(try UpdateSignatureVerifier.verify(appAt: base.appendingPathComponent("Good/PulseBar.app")))
        XCTAssertThrowsError(try UpdateSignatureVerifier.verify(appAt: base.appendingPathComponent("Tampered/PulseBar.app")))
        XCTAssertThrowsError(try UpdateSignatureVerifier.verify(appAt: base.appendingPathComponent("Other/PulseBar.app")))
        // The installed copy is ad-hoc signed (pre-notarization build).
        let installed = URL(fileURLWithPath: "/Applications/PulseBar.app")
        if FileManager.default.fileExists(atPath: installed.path) {
            XCTAssertThrowsError(try UpdateSignatureVerifier.verify(appAt: installed))
        }
    }
}
