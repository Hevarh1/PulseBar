import Foundation
import Darwin

public final class CPUReader: @unchecked Sendable {
    private var previousCPULoad: host_cpu_load_info?

    /// True after at least one host_statistics sample (delta baselines exist).
    var hasSamplingBaseline: Bool { previousCPULoad != nil }
    public let chipModel: String
    public let coreCount: Int

    public init() {
        self.chipModel = CPUReader.readChipModel()
        self.coreCount = ProcessInfo.processInfo.processorCount
    }

    public func sample() -> CPUSample {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return CPUSample(chipModel: chipModel, coreCount: coreCount)
        }

        guard let prev = previousCPULoad else {
            previousCPULoad = cpuLoadInfo
            return CPUSample(chipModel: chipModel, coreCount: coreCount)
        }

        let userDelta = Double(cpuLoadInfo.cpu_ticks.0 - prev.cpu_ticks.0)
        let systemDelta = Double(cpuLoadInfo.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDelta = Double(cpuLoadInfo.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDelta = Double(cpuLoadInfo.cpu_ticks.3 - prev.cpu_ticks.3)

        previousCPULoad = cpuLoadInfo

        let totalTicks = userDelta + systemDelta + idleDelta + niceDelta
        guard totalTicks > 0 else {
            return CPUSample(chipModel: chipModel, coreCount: coreCount)
        }

        let userPercent = ((userDelta + niceDelta) / totalTicks) * 100.0
        let sysPercent = (systemDelta / totalTicks) * 100.0
        let idlePercent = (idleDelta / totalTicks) * 100.0
        let totalPercent = userPercent + sysPercent

        return CPUSample(
            userPercentage: max(0.0, min(100.0, userPercent)),
            systemPercentage: max(0.0, min(100.0, sysPercent)),
            idlePercentage: max(0.0, min(100.0, idlePercent)),
            totalPercentage: max(0.0, min(100.0, totalPercent)),
            chipModel: chipModel,
            coreCount: coreCount,
            timestamp: Date()
        )
    }

    private static func readChipModel() -> String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var brand = [CChar](repeating: 0, count: Int(size))
            sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
            let brandStr = String(cString: brand).trimmingCharacters(in: .whitespacesAndNewlines)
            if !brandStr.isEmpty {
                return brandStr
            }
        }
        return "Apple Silicon"
    }
}
