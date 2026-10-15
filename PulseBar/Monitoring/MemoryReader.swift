import Foundation
import Darwin

public final class MemoryReader: @unchecked Sendable {
    public let totalBytes: UInt64
    private let pageSize: UInt64

    public init() {
        self.totalBytes = ProcessInfo.processInfo.physicalMemory
        var ps: vm_size_t = 0
        _ = host_page_size(mach_host_self(), &ps)
        self.pageSize = ps > 0 ? UInt64(ps) : 16384
    }

    public func sample() -> MemorySample {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemorySample(
                usedBytes: 0,
                totalBytes: totalBytes,
                freeBytes: totalBytes,
                compressedBytes: 0,
                wiredBytes: 0,
                swapUsedBytes: 0,
                pressureLevel: .normal,
                timestamp: Date()
            )
        }

        let wiredBytes = UInt64(vmStats.wire_count) * pageSize
        let compressedBytes = UInt64(vmStats.compressor_page_count) * pageSize
        let freeBytes = UInt64(vmStats.free_count) * pageSize

        // Match Activity Monitor "Memory Used":
        // App (anonymous/internal) + Wired + Compressed.
        // Do NOT count inactive file cache — that was the ~95% bloated reading.
        let appBytes = UInt64(vmStats.internal_page_count) * pageSize
        let usedBytes = min(totalBytes, appBytes + wiredBytes + compressedBytes)

        let swapUsed = readSwapUsage()
        let pressure = determineMemoryPressure(
            usedBytes: usedBytes,
            totalBytes: totalBytes,
            compressedBytes: compressedBytes
        )

        return MemorySample(
            usedBytes: usedBytes,
            totalBytes: totalBytes,
            freeBytes: totalBytes > usedBytes ? totalBytes - usedBytes : freeBytes,
            compressedBytes: compressedBytes,
            wiredBytes: wiredBytes,
            swapUsedBytes: swapUsed,
            pressureLevel: pressure,
            timestamp: Date()
        )
    }

    private func readSwapUsage() -> UInt64 {
        var size: size_t = MemoryLayout<xsw_usage>.size
        var swapUsage = xsw_usage()
        if sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0) == 0 {
            return UInt64(swapUsage.xsu_used)
        }
        return 0
    }

    private func determineMemoryPressure(usedBytes: UInt64, totalBytes: UInt64, compressedBytes: UInt64) -> MemoryPressureLevel {
        guard totalBytes > 0 else { return .normal }
        let ratio = Double(usedBytes) / Double(totalBytes)
        let compressedRatio = Double(compressedBytes) / Double(totalBytes)

        if ratio > 0.90 || compressedRatio > 0.35 {
            return .critical
        } else if ratio > 0.75 || compressedRatio > 0.15 {
            return .warning
        } else {
            return .normal
        }
    }

    /// Best-effort ask for reclaimable caches. macOS may ignore this; “Memory Used”
    /// often will not drop. Prefers `memory_pressure` (no root); falls back to `purge`.
    @discardableResult
    public func requestMemoryPurge() -> Bool {
        if runQuiet("/usr/bin/memory_pressure", arguments: ["-l", "warn"]) {
            return true
        }
        // Root-only; fails silently for normal users.
        return runQuiet("/usr/sbin/purge", arguments: [])
    }

    private func runQuiet(_ path: String, arguments: [String]) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
