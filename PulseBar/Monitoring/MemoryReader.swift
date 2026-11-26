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
        // Prefer the kernel's level: the ratio heuristic said "Critical" at
        // 78% used while macOS itself only reported "warn".
        let pressure = Self.kernelPressureLevel() ?? determineMemoryPressure(
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

    /// The kernel's own memory-pressure level (what Activity Monitor's
    /// pressure graph shows), or nil when the sysctl is unavailable.
    /// 1 = normal, 2 = warn, 4 = critical.
    public static func kernelPressureLevel() -> MemoryPressureLevel? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            return nil
        }
        switch level {
        case 1: return .normal
        case 2: return .warning
        case 4: return .critical
        default: return nil
        }
    }

    /// Bytes the system could hand out right now without paging: free plus
    /// speculative pages. `purge` moves inactive file cache into this pool, so
    /// the before/after delta is what a purge actually reclaimed.
    public func immediatelyFreeBytes() -> UInt64 {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(vmStats.free_count + vmStats.speculative_count) * pageSize
    }

    /// Flushes reclaimable file cache with `/usr/sbin/purge`. purge needs root,
    /// so macOS shows its standard administrator prompt. Blocks the calling
    /// thread for the prompt and the purge: never call on the main thread.
    ///
    /// (The previous `memory_pressure -l warn` allocated real memory until the
    /// system hit warning pressure, which froze the dashboard and briefly made
    /// memory worse; its simulate mode needs root as well.)
    public func purgeWithAdminPrompt() -> MemoryPurgeResult {
        let before = immediatelyFreeBytes()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = [
            "-e",
            "do shell script \"/usr/sbin/purge\" with prompt \"PulseBar wants to free inactive memory.\" with administrator privileges"
        ]
        let errorPipe = Pipe()
        task.standardOutput = FileHandle.nullDevice
        task.standardError = errorPipe
        do {
            try task.run()
        } catch {
            return .failed(error.localizedDescription)
        }
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // -128: the user pressed Cancel on the password prompt.
            if message.contains("-128") { return .cancelled }
            return .failed(message.isEmpty ? "purge exited with status \(task.terminationStatus)" : message)
        }
        let after = immediatelyFreeBytes()
        return .freed(after > before ? after - before : 0)
    }
}

public enum MemoryPurgeResult: Equatable, Sendable {
    case freed(UInt64)
    case cancelled
    case failed(String)
}
