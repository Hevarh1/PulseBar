import Foundation
import IOKit
import Metal

/// GPU name, core count and live utilization.
///
/// Utilization comes from the GPU driver's `PerformanceStatistics` in the
/// IORegistry (public IOKit, no special permissions). Reading it is a single
/// registry property fetch, well under a millisecond.
public final class GPUReader: @unchecked Sendable {
    public let modelName: String
    public let coreCount: Int?

    /// Every accelerator that publishes statistics (two on dual-GPU Intel Macs).
    private let accelerators: [io_registry_entry_t]

    public init() {
        var found: [io_registry_entry_t] = []
        var model: String?
        var cores: Int?
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                if Self.statistics(of: service) != nil {
                    found.append(service)
                    model = model ?? Self.property(service, "model") as? String
                    cores = cores ?? (Self.property(service, "gpu-core-count") as? NSNumber)?.intValue
                } else {
                    IOObjectRelease(service)
                }
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        accelerators = found
        modelName = model ?? MTLCreateSystemDefaultDevice()?.name ?? "GPU"
        coreCount = cores
    }

    deinit {
        accelerators.forEach { IOObjectRelease($0) }
    }

    public func sample() -> GPUSample {
        // With two GPUs, report the busier one.
        let busiest = accelerators
            .compactMap { Self.statistics(of: $0) }
            .max { (Self.utilization(in: $0) ?? -1) < (Self.utilization(in: $1) ?? -1) }

        return GPUSample(
            modelName: modelName,
            coreCount: coreCount,
            isAvailable: true,
            utilizationPercent: busiest.flatMap(Self.utilization),
            rendererPercent: busiest.flatMap { Self.percent($0["Renderer Utilization %"]) },
            tilerPercent: busiest.flatMap { Self.percent($0["Tiler Utilization %"]) },
            memoryInUseBytes: (busiest?["In use system memory"] as? NSNumber)?.uint64Value,
            timestamp: Date()
        )
    }

    /// Apple silicon and AMD report "Device Utilization %"; Intel iGPUs "GPU Activity(%)".
    private static func utilization(in stats: [String: Any]) -> Double? {
        percent(stats["Device Utilization %"]) ?? percent(stats["GPU Activity(%)"])
    }

    private static func percent(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        return min(100, max(0, number.doubleValue))
    }

    private static func statistics(of entry: io_registry_entry_t) -> [String: Any]? {
        property(entry, "PerformanceStatistics") as? [String: Any]
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
