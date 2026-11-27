import XCTest
@testable import PulseBar

final class FanTests: XCTestCase {
    func testDecodesAppleSiliconFloat() {
        // 2340.0 as a little-endian Float32, the way Apple Silicon reports F0Ac.
        let bytes = withUnsafeBytes(of: Float(2340).bitPattern.littleEndian) { Array($0) }
        XCTAssertEqual(SMCValue.decode(type: "flt ", bytes: bytes), 2340)
    }

    func testDecodesIntelFixedPointFanSpeed() {
        // fpe2: 2340 RPM × 4 = 0x2490, big-endian.
        XCTAssertEqual(SMCValue.decode(type: "fpe2", bytes: [0x24, 0x90]), 2340)
    }

    func testDecodesTemperatureAndIntegers() {
        XCTAssertEqual(SMCValue.decode(type: "sp78", bytes: [0x2A, 0x80]), 42.5)
        XCTAssertEqual(SMCValue.decode(type: "ui8 ", bytes: [2]), 2)
        XCTAssertEqual(SMCValue.decode(type: "ui16", bytes: [0x01, 0x00]), 256)
        XCTAssertEqual(SMCValue.decode(type: "ui32", bytes: [0, 0, 0x01, 0x02]), 258)
    }

    func testRejectsUnknownOrShortData() {
        XCTAssertNil(SMCValue.decode(type: "flag", bytes: [1]))
        XCTAssertNil(SMCValue.decode(type: "flt ", bytes: [0, 0]))
        XCTAssertNil(SMCValue.decode(type: "fpe2", bytes: []))
    }

    func testFourCharacterCodes() {
        XCTAssertEqual(SMCValue.fourCC("FNum"), 0x464E_756D)
        XCTAssertNil(SMCValue.fourCC("F0A"))
        XCTAssertEqual(SMCValue.typeString(0x666C_7420), "flt ")
    }

    func testFanLoadAndStoppedState() {
        let spinning = FanSample(fanCount: 2, fanSpeeds: [2950, 0], maxSpeeds: [5900, 0], isFanless: false)
        XCTAssertEqual(spinning.load(0) ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertNil(spinning.load(1), "No maximum means no load fraction")
        XCTAssertFalse(spinning.allStopped)

        let stopped = FanSample(fanCount: 1, fanSpeeds: [0], maxSpeeds: [5900], isFanless: false)
        XCTAssertTrue(stopped.allStopped)

        let unreadable = FanSample(fanCount: 1, isFanless: false)
        XCTAssertFalse(unreadable.allStopped, "Unknown speed is not the same as stopped")
    }

    func testSensorReaderReportsAConsistentSample() {
        let sample = SensorReader().sampleFans()
        if sample.isFanless {
            XCTAssertEqual(sample.fanCount, 0)
            XCTAssertTrue(sample.fanSpeeds.isEmpty)
        } else {
            XCTAssertGreaterThan(sample.fanCount, 0)
            XCTAssertTrue(sample.fanSpeeds.isEmpty || sample.fanSpeeds.count == sample.fanCount)
        }
    }
}
