import Foundation
import IOKit

/// Fan count and speeds from the SMC (`FNum`, `F<n>Ac`, `F<n>Mx`), the same
/// keys on Apple Silicon (`flt `) and Intel (`fpe2`). Apple Silicon Macs have
/// no `AppleSMCFan` IOKit services, so counting those missed every fan on a
/// MacBook Pro; that is now only a fallback when the SMC can't be opened.
public final class SensorReader: @unchecked Sendable {
    private let smc: SMCConnection
    /// Fan count and maximum speeds don't change while the app runs; read them once.
    private var cachedLayout: (count: Int, maxSpeeds: [Double])?
    private let lock = NSLock()

    public init() {
        self.smc = .shared
    }

    public func sampleFans() -> FanSample {
        let layout = fanLayout()
        guard layout.count > 0 else {
            return FanSample(fanCount: 0, isFanless: true, statusDescription: "No fan detected", timestamp: Date())
        }

        let speeds = (0..<layout.count).compactMap { index -> Double? in
            guard let rpm = smc.number("F\(index)Ac"), rpm >= 0, rpm < 20_000 else { return nil }
            return rpm
        }
        let readable = speeds.count == layout.count
        let fans = "\(layout.count) fan\(layout.count == 1 ? "" : "s")"
        return FanSample(
            fanCount: layout.count,
            fanSpeeds: readable ? speeds : [],
            maxSpeeds: readable ? layout.maxSpeeds : [],
            isFanless: false,
            statusDescription: readable ? fans : "\(fans) • speed unavailable",
            timestamp: Date()
        )
    }

    private func fanLayout() -> (count: Int, maxSpeeds: [Double]) {
        lock.lock()
        defer { lock.unlock() }
        if let cachedLayout { return cachedLayout }

        let layout: (count: Int, maxSpeeds: [Double])
        if smc.isAvailable, let reported = smc.number("FNum") {
            let count = max(0, min(Int(reported), 8))
            let maxSpeeds = (0..<count).map { smc.number("F\($0)Mx") ?? 0 }
            layout = (count, maxSpeeds)
        } else {
            layout = (Self.countFanServices(), [])
        }
        cachedLayout = layout
        return layout
    }

    /// Intel-era fallback: one `AppleSMCFan` service per fan.
    private static func countFanServices() -> Int {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMCFan"), &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }
        var count = 0
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            count += 1
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return count
    }
}
