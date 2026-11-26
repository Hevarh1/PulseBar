import XCTest
@testable import PulseBar

@MainActor
final class MemoryCleanerTests: XCTestCase {
    func testSummaryTreatsTinyDeltaAsNoise() {
        XCTAssertEqual(MemoryCleaner.summary(freedBytes: 0), "Already lean")
        XCTAssertEqual(MemoryCleaner.summary(freedBytes: 10 * 1024 * 1024), "Already lean")
    }

    func testSummaryReportsReclaimedAmount() {
        let summary = MemoryCleaner.summary(freedBytes: 2 * 1024 * 1024 * 1024)
        XCTAssertTrue(summary.hasPrefix("Freed "), summary)
        XCTAssertTrue(summary.contains("GB"), summary)
    }

    func testCleanerStartsIdle() {
        XCTAssertEqual(MemoryCleaner.shared.phase, .idle)
    }
}

final class MemoryPressureTests: XCTestCase {
    func testKernelPressureLevelIsReadable() {
        // Every supported macOS publishes this sysctl without root.
        XCTAssertNotNil(MemoryReader.kernelPressureLevel())
    }

    func testImmediatelyFreeBytesIsPositive() {
        XCTAssertGreaterThan(MemoryReader().immediatelyFreeBytes(), 0)
    }
}
