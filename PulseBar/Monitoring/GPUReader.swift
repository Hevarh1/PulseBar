import Foundation
import Metal

public final class GPUReader: @unchecked Sendable {
    public let modelName: String

    public init() {
        if let device = MTLCreateSystemDefaultDevice() {
            self.modelName = device.name
        } else {
            self.modelName = "Apple M-Series GPU"
        }
    }

    public func sample() -> GPUSample {
        // Public macOS Metal APIs expose the GPU name and characteristics.
        // As specified in the implementation plan, unsupported private sub-counters
        // (device, render, tile) display an honest unavailable state rather than private API scraping.
        return GPUSample(
            modelName: modelName,
            coreCount: nil,
            isAvailable: true,
            utilizationPercent: nil,
            timestamp: Date()
        )
    }
}
