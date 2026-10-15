import Foundation
import IOKit

public final class SensorReader: @unchecked Sendable {
    /// Fan presence is stable for a process lifetime; probe once and reuse.
    private var cachedFanCount: Int?
    private let lock = NSLock()

    public init() {}

    public func sampleFans() -> FanSample {
        let fanCount = detectedFanCount()
        if fanCount == 0 {
            return FanSample(
                fanCount: 0,
                fanSpeeds: [],
                isFanless: true,
                statusDescription: "No fan detected",
                timestamp: Date()
            )
        }

        // Public APIs do not expose reliable RPM on modern Macs without private SMC keys.
        // Do not invent placeholder speeds (e.g. 1200 RPM) or re-walk IOKit every tick.
        return FanSample(
            fanCount: fanCount,
            fanSpeeds: [],
            isFanless: false,
            statusDescription: "\(fanCount) fan\(fanCount == 1 ? "" : "s") present • RPM unavailable",
            timestamp: Date()
        )
    }

    private func detectedFanCount() -> Int {
        lock.lock()
        defer { lock.unlock() }

        if let cachedFanCount {
            return cachedFanCount
        }

        let count = probeFanCount()
        cachedFanCount = count
        return count
    }

    private func probeFanCount() -> Int {
        var count = 0
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleSMCFan")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            count += 1
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return count
    }
}
