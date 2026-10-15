import XCTest
@testable import PulseBar

final class UpdateVersionTests: XCTestCase {
    func testNormalizeStripsVPrefix() {
        XCTAssertEqual(Version.normalize("v1.2.3"), "1.2.3")
        XCTAssertEqual(Version.normalize("1.2.3"), "1.2.3")
    }

    func testCompareOrdersSemver() {
        XCTAssertEqual(Version.compare("1.1.2", "1.1.1"), .orderedDescending)
        XCTAssertEqual(Version.compare("1.0.9", "1.1.0"), .orderedAscending)
        XCTAssertEqual(Version.compare("v1.2.0", "1.2.0"), .orderedSame)
        XCTAssertEqual(Version.compare("1.10.0", "1.9.0"), .orderedDescending)
    }
}
