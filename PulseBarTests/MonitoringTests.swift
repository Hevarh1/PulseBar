import XCTest
import SwiftUI
@testable import PulseBar

final class MonitoringTests: XCTestCase {

    func testCPUSampleCalculations() {
        let sample = CPUSample(
            userPercentage: 15.0,
            systemPercentage: 5.0,
            idlePercentage: 80.0,
            totalPercentage: 20.0,
            chipModel: "Apple M4",
            coreCount: 10
        )

        XCTAssertEqual(sample.totalPercentage, 20.0)
        XCTAssertEqual(sample.userPercentage, 15.0)
        XCTAssertEqual(sample.systemPercentage, 5.0)
        XCTAssertEqual(sample.idlePercentage, 80.0)
        XCTAssertEqual(sample.chipModel, "Apple M4")
        XCTAssertEqual(sample.coreCount, 10)
    }

    func testMemorySampleWith16GBRAM() {
        let sixteenGB: UInt64 = 16 * 1024 * 1024 * 1024
        let eightGBUsed: UInt64 = 8 * 1024 * 1024 * 1024

        let sample16 = MemorySample(
            usedBytes: eightGBUsed,
            totalBytes: sixteenGB,
            freeBytes: sixteenGB - eightGBUsed,
            compressedBytes: 1024 * 1024 * 512,
            wiredBytes: 1024 * 1024 * 1024 * 2,
            swapUsedBytes: 0,
            pressureLevel: .normal
        )

        XCTAssertEqual(sample16.totalBytes, sixteenGB)
        XCTAssertEqual(sample16.usedBytes, eightGBUsed)
        XCTAssertEqual(sample16.usedPercentage, 50.0, accuracy: 0.01)
        XCTAssertEqual(sample16.pressureLevel, .normal)
    }

    func testMemorySampleWith24GBRAM() {
        let twentyFourGB: UInt64 = 24 * 1024 * 1024 * 1024
        let twelveGBUsed: UInt64 = 12 * 1024 * 1024 * 1024

        let sample24 = MemorySample(
            usedBytes: twelveGBUsed,
            totalBytes: twentyFourGB,
            freeBytes: twentyFourGB - twelveGBUsed,
            compressedBytes: 1024 * 1024 * 1024,
            wiredBytes: 1024 * 1024 * 1024 * 3,
            swapUsedBytes: 0,
            pressureLevel: .normal
        )

        XCTAssertEqual(sample24.totalBytes, twentyFourGB)
        XCTAssertEqual(sample24.usedBytes, twelveGBUsed)
        XCTAssertEqual(sample24.usedPercentage, 50.0, accuracy: 0.01)
    }

    func testMemorySampleHighPressure() {
        let sixteenGB: UInt64 = 16 * 1024 * 1024 * 1024
        let fifteenGBUsed: UInt64 = UInt64(Double(sixteenGB) * 0.95)

        let sample = MemorySample(
            usedBytes: fifteenGBUsed,
            totalBytes: sixteenGB,
            freeBytes: sixteenGB - fifteenGBUsed,
            compressedBytes: 1024 * 1024 * 1024 * 4,
            wiredBytes: 1024 * 1024 * 1024 * 5,
            swapUsedBytes: 1024 * 1024 * 1024 * 2,
            pressureLevel: .critical
        )

        XCTAssertEqual(sample.pressureLevel, .critical)
        XCTAssertGreaterThan(sample.usedPercentage, 90.0)
    }

    func testDiskSampleUsedPercentage() {
        let total: UInt64 = 500 * 1000 * 1000 * 1000
        let used: UInt64 = 250 * 1000 * 1000 * 1000

        let sample = DiskSample(
            volumeName: "Macintosh HD",
            usedBytes: used,
            totalBytes: total,
            freeBytes: total - used,
            readBytesPerSec: 1024 * 1024 * 15,
            writeBytesPerSec: 1024 * 1024 * 5
        )

        XCTAssertEqual(sample.usedPercentage, 50.0, accuracy: 0.01)
        XCTAssertEqual(sample.volumeName, "Macintosh HD")
    }

    func testFanlessSampleReporting() {
        let fanSample = FanSample(
            fanCount: 0,
            fanSpeeds: [],
            isFanless: true,
            statusDescription: "No fan detected"
        )

        XCTAssertTrue(fanSample.isFanless)
        XCTAssertEqual(fanSample.fanCount, 0)
        XCTAssertEqual(fanSample.statusDescription, "No fan detected")
    }

    @MainActor
    func testDashboardViewRendering() {
        print("Testing CPUCard...")
        _ = NSHostingView(rootView: CPUCard(cpu: CPUSample())).fittingSize

        print("Testing MemoryCard...")
        _ = NSHostingView(rootView: MemoryCard(memory: MemorySample(), history: [], onFreeUp: {})).fittingSize

        print("Testing StorageCard...")
        _ = NSHostingView(rootView: StorageCard(disk: DiskSample())).fittingSize

        print("Testing NetworkCard...")
        _ = NSHostingView(rootView: NetworkCard(network: NetworkSample(), downloadHistory: [])).fittingSize

        print("Testing GPUCard...")
        _ = NSHostingView(rootView: GPUCard(gpu: GPUSample())).fittingSize

        print("Testing FanCard...")
        _ = NSHostingView(rootView: FanCard(fan: FanSample())).fittingSize

        print("Testing UtilityGrid...")
        _ = NSHostingView(rootView: UtilityGrid()).fittingSize

        print("Testing DashboardView...")
        let view = DashboardView()
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        XCTAssertGreaterThan(size.width, 0)
    }
}
