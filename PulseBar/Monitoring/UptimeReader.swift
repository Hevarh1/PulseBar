import Foundation
import Darwin

public final class UptimeReader: @unchecked Sendable {
    public init() {}

    public func sample() -> UptimeSample {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        let result = sysctl(&mib, 2, &bootTime, &size, nil, 0)
        let now = Date()

        if result == 0 {
            let bootDate = Date(timeIntervalSince1970: Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000.0)
            let uptime = max(0, now.timeIntervalSince(bootDate))
            return UptimeSample(bootTime: bootDate, uptimeSeconds: uptime, timestamp: now)
        } else {
            let uptime = ProcessInfo.processInfo.systemUptime
            let bootDate = now.addingTimeInterval(-uptime)
            return UptimeSample(bootTime: bootDate, uptimeSeconds: uptime, timestamp: now)
        }
    }
}
