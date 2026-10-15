import Foundation
import IOKit
import IOKit.storage

public final class DiskReader: @unchecked Sendable {
    private var lastSampleTime: Date?
    private var lastReadBytes: UInt64?
    private var lastWriteBytes: UInt64?

    public init() {}

    /// When `includeIOThroughput` is false, skips the IOKit block-storage walk
    /// (capacity-only). Full dashboard samples pass `true`.
    public func sample(includeIOThroughput: Bool = true) -> DiskSample {
        let now = Date()
        var volumeName = "Macintosh HD"
        var totalBytes: UInt64 = 0
        var freeBytes: UInt64 = 0

        let url = URL(fileURLWithPath: "/")
        if let values = try? url.resourceValues(forKeys: [
            .volumeLocalizedNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]) {
            volumeName = values.volumeLocalizedName ?? "Macintosh HD"
            totalBytes = UInt64(values.volumeTotalCapacity ?? 0)
            freeBytes = UInt64(values.volumeAvailableCapacity ?? 0)
        } else if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            totalBytes = (attrs[.systemSize] as? NSNumber)?.uint64Value ?? 0
            freeBytes = (attrs[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
        }

        let usedBytes = totalBytes > freeBytes ? totalBytes - freeBytes : 0

        var readRate: Double = 0
        var writeRate: Double = 0

        if includeIOThroughput {
            let (totalRead, totalWrite) = readBlockStorageBytes()

            if let lastTime = lastSampleTime,
               let lastRead = lastReadBytes,
               let lastWrite = lastWriteBytes {
                let elapsed = now.timeIntervalSince(lastTime)
                if elapsed > 0 {
                    let readDelta = totalRead >= lastRead ? Double(totalRead - lastRead) : 0
                    let writeDelta = totalWrite >= lastWrite ? Double(totalWrite - lastWrite) : 0
                    readRate = readDelta / elapsed
                    writeRate = writeDelta / elapsed
                }
            }

            lastSampleTime = now
            lastReadBytes = totalRead
            lastWriteBytes = totalWrite
        }

        return DiskSample(
            volumeName: volumeName,
            usedBytes: usedBytes,
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            readBytesPerSec: readRate,
            writeBytesPerSec: writeRate,
            isBootVolume: true,
            timestamp: now
        )
    }

    private func readBlockStorageBytes() -> (read: UInt64, write: UInt64) {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching(kIOBlockStorageDriverClass)
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                if let r = stats["Bytes (Read)"] as? NSNumber {
                    totalRead += r.uint64Value
                }
                if let w = stats["Bytes (Write)"] as? NSNumber {
                    totalWrite += w.uint64Value
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }

        return (totalRead, totalWrite)
    }
}
