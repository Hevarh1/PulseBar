import Foundation
import Security

/// Checks that a downloaded update was signed by PulseBar's own Developer ID
/// before it may replace the installed app.
///
/// Without this, anyone able to publish a GitHub release on the repository
/// (a stolen login or token) could ship arbitrary code to every installed
/// copy: URLSession downloads carry no quarantine flag, so Gatekeeper never
/// looks at them.
enum UpdateSignatureVerifier {
    static let bundleIdentifier = "com.pulsebar.app"
    /// Team ID of "Developer ID Application: Hemin Ibrahim". Changing the
    /// signing team means shipping one release that trusts both IDs first.
    static let teamIdentifier = "EE59RGG9JM"

    /// Apple-issued Developer ID certificate (the 1.2.840.113635.100.6.1.13
    /// marker) for this team, and this app's bundle identifier.
    static var developerIDRequirement: String {
        """
        anchor apple generic \
        and identifier "\(bundleIdentifier)" \
        and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ \
        and certificate leaf[subject.OU] = "\(teamIdentifier)"
        """
    }

    enum Failure: LocalizedError, Equatable {
        case unreadable(OSStatus)
        case badRequirement(OSStatus)
        case rejected(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let status):
                return "The downloaded update couldn’t be read for verification (\(status))."
            case .badRequirement(let status):
                return "The update signature rule is invalid (\(status))."
            case .rejected(let reason):
                return "The downloaded update isn’t signed by PulseBar’s developer, so it wasn’t installed. \(reason)"
            }
        }
    }

    /// Throws unless the bundle at `appURL` is intact (every file, nested
    /// code included) and satisfies `requirement`.
    static func verify(appAt appURL: URL, requirement: String = developerIDRequirement) throws {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            throw Failure.unreadable(createStatus)
        }

        var secRequirement: SecRequirement?
        let requirementStatus = SecRequirementCreateWithString(requirement as CFString, [], &secRequirement)
        guard requirementStatus == errSecSuccess, let secRequirement else {
            throw Failure.badRequirement(requirementStatus)
        }

        let flags = SecCSFlags(rawValue:
            kSecCSCheckAllArchitectures
            | kSecCSCheckNestedCode
            | kSecCSStrictValidate
        )
        var cfError: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(staticCode, flags, secRequirement, &cfError)
        guard status == errSecSuccess else {
            let reason = cfError?.takeRetainedValue().localizedDescription ?? "OSStatus \(status)."
            throw Failure.rejected(reason)
        }
    }
}
