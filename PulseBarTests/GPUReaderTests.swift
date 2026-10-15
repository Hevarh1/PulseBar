import XCTest
@testable import PulseBar

final class GPUReaderTests: XCTestCase {
    func testReadsUtilizationWhenTheDriverPublishesIt() throws {
        let reader = GPUReader()
        let sample = reader.sample()
        XCTAssertFalse(sample.modelName.isEmpty)
        // Virtual machines and some CI hosts publish no GPU statistics.
        guard let utilization = sample.utilizationPercent else {
            throw XCTSkip("This GPU publishes no PerformanceStatistics")
        }
        XCTAssertTrue((0...100).contains(utilization))
        if let renderer = sample.rendererPercent { XCTAssertTrue((0...100).contains(renderer)) }

        // Cheap enough to read every second while the dashboard is open.
        let start = Date()
        for _ in 0..<100 { _ = reader.sample() }
        let perRead = Date().timeIntervalSince(start) / 100
        print("GPU read: \(String(format: "%.3f", perRead * 1000)) ms, utilization \(Int(utilization))%, cores \(sample.coreCount.map(String.init) ?? "?"), memory \(sample.memoryInUseBytes ?? 0)")
        XCTAssertLessThan(perRead, 0.005)
    }
}
