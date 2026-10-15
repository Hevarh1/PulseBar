import XCTest
@testable import PulseBar

final class FormattingTests: XCTestCase {

    func testByteFormatting() {
        let oneKB: UInt64 = 1024
        let oneMB: UInt64 = 1024 * 1024
        let oneGB: UInt64 = 1024 * 1024 * 1024
        let sixteenGB: UInt64 = 16 * 1024 * 1024 * 1024
        let twentyFourGB: UInt64 = 24 * 1024 * 1024 * 1024

        XCTAssertFalse(Formatters.formatBytes(oneKB).isEmpty)
        XCTAssertFalse(Formatters.formatBytes(oneMB).isEmpty)
        XCTAssertFalse(Formatters.formatBytes(oneGB).isEmpty)
        XCTAssertTrue(Formatters.formatBytes(sixteenGB).contains("16") || Formatters.formatBytes(sixteenGB).contains("17"))
        XCTAssertTrue(Formatters.formatBytes(twentyFourGB).contains("24") || Formatters.formatBytes(twentyFourGB).contains("25"))
    }

    func testRateFormatting() {
        XCTAssertEqual(Formatters.formatRate(500), "500 B/s")
        XCTAssertEqual(Formatters.formatRate(1024 * 1.5), "1.5 KB/s")
        XCTAssertEqual(Formatters.formatRate(1024 * 1024 * 4.2), "4.2 MB/s")
        XCTAssertEqual(Formatters.formatRate(1024 * 1024 * 1024 * 1.25), "1.25 GB/s")
    }

    func testPercentageFormatting() {
        XCTAssertEqual(Formatters.formatPercentage(0.0), "0.0%")
        XCTAssertEqual(Formatters.formatPercentage(45.67), "45.7%")
        XCTAssertEqual(Formatters.formatPercentage(100.0), "100.0%")
        XCTAssertEqual(Formatters.formatPercentage(150.0), "100.0%") // clamped
        XCTAssertEqual(Formatters.formatPercentage(-10.0), "0.0%")  // clamped
    }

    func testTemperatureFormatting() {
        XCTAssertEqual(Formatters.formatTemperature(40.0, unit: .celsius), "40°C")
        XCTAssertEqual(Formatters.formatTemperature(100.0, unit: .celsius), "100°C")

        // 0°C -> 32°F
        XCTAssertEqual(Formatters.formatTemperature(0.0, unit: .fahrenheit), "32°F")
        // 100°C -> 212°F
        XCTAssertEqual(Formatters.formatTemperature(100.0, unit: .fahrenheit), "212°F")
    }

    func testUptimeFormatting() {
        XCTAssertEqual(Formatters.formatUptime(seconds: 45), "0m")
        XCTAssertEqual(Formatters.formatUptime(seconds: 120), "2m")
        XCTAssertEqual(Formatters.formatUptime(seconds: 3600 * 2 + 60 * 15), "2h 15m")
        XCTAssertEqual(Formatters.formatUptime(seconds: 86400 * 3 + 3600 * 4 + 60 * 22), "3d 4h 22m")
    }
}
