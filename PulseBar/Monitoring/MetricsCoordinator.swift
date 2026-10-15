import Foundation
import Combine

@MainActor
public final class MetricsCoordinator: ObservableObject {
    public static let shared = MetricsCoordinator()

    /// Menu-bar refresh while the popover is closed — ~1 Hz live updates.
    public static let idleSamplingInterval: TimeInterval = 1.0

    @Published public private(set) var currentSnapshot: SystemSnapshot = .empty
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isDashboardVisible: Bool = false
    @Published public private(set) var networkGraphMaxBytesPerSec: Double = 102_400
    /// Bumps each successful sample so the UI can pulse / animate refresh.
    @Published public private(set) var sampleTick: UInt64 = 0

    private let cpuReader = CPUReader()
    private let memoryReader = MemoryReader()
    private let diskReader = DiskReader()
    private let networkReader = NetworkReader()
    private let batteryReader = BatteryReader()
    private let thermalReader = ThermalReader()
    private let sensorReader = SensorReader()
    private let uptimeReader = UptimeReader()
    private let gpuReader = GPUReader()

    private var timerTask: Task<Void, Never>?
    private let maxHistoryLength = 60

    private var cpuHistory: [Double] = []
    private var cpuUserHistory: [Double] = []
    private var cpuSystemHistory: [Double] = []
    private var memoryHistory: [Double] = []
    private var networkDownHistory: [Double] = []
    private var networkUpHistory: [Double] = []
    private var diskReadHistory: [Double] = []
    private var diskWriteHistory: [Double] = []
    private var gpuHistory: [Double] = []

    /// Light EMA so menu-bar / dashboard numbers tick smoothly instead of jumping.
    private var smoothedCPUTotal: Double?
    private var smoothedCPUUser: Double?
    private var smoothedCPUSystem: Double?
    private var smoothedMemoryPercent: Double?
    private let displaySmoothAlpha: Double = 0.42

    private init() {
        restartSampling()
    }

    /// Call from the menu-bar popover show/close path so sampling can switch tiers.
    public func setDashboardVisible(_ visible: Bool) {
        guard isDashboardVisible != visible else { return }
        isDashboardVisible = visible
        // Keep graph histories across open/close so reopen feels continuous, not empty→jump.
        restartSampling()
        guard visible else { return }
        Task {
            await collectAndApplyFullSample(
                cpuReader: cpuReader,
                memoryReader: memoryReader,
                diskReader: diskReader,
                networkReader: networkReader,
                batteryReader: batteryReader,
                thermalReader: thermalReader,
                sensorReader: sensorReader,
                uptimeReader: uptimeReader,
                gpuReader: gpuReader
            )
        }
    }

    /// Restart the sampling loop using saved settings and current dashboard visibility.
    public func restartSampling() {
        timerTask?.cancel()
        isRunning = true

        let dashboardVisible = isDashboardVisible
        // ~1s in the menu bar; preferences control open-dashboard rate.
        let openInterval = max(0.5, AppSettings.shared.samplingInterval)
        let interval = dashboardVisible ? openInterval : Self.idleSamplingInterval
        let priority: TaskPriority = dashboardVisible ? .userInitiated : .utility

        let cpuReader = self.cpuReader
        let memoryReader = self.memoryReader
        let diskReader = self.diskReader
        let networkReader = self.networkReader
        let batteryReader = self.batteryReader
        let thermalReader = self.thermalReader
        let sensorReader = self.sensorReader
        let uptimeReader = self.uptimeReader
        let gpuReader = self.gpuReader

        timerTask = Task.detached(priority: priority) { [weak self] in
            let baselinesReady = cpuReader.hasSamplingBaseline && networkReader.hasSamplingBaseline
            if !baselinesReady {
                // Prime CPU/network counters so the first published sample is a real delta (not 0%).
                _ = cpuReader.sample()
                _ = networkReader.sample(includeIdentity: false)
                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            while !Task.isCancelled {
                let menuBar = await MainActor.run {
                    MenuBarSamplingFlags(settings: AppSettings.shared)
                }

                if dashboardVisible {
                    await self?.collectAndApplyFullSample(
                        cpuReader: cpuReader,
                        memoryReader: memoryReader,
                        diskReader: diskReader,
                        networkReader: networkReader,
                        batteryReader: batteryReader,
                        thermalReader: thermalReader,
                        sensorReader: sensorReader,
                        uptimeReader: uptimeReader,
                        gpuReader: gpuReader
                    )
                } else if menuBar.needsAnySample {
                    let previous: SystemSnapshot
                    if let coordinator = self {
                        previous = await MainActor.run { coordinator.currentSnapshot }
                    } else {
                        break
                    }

                    let cpu = menuBar.cpu ? cpuReader.sample() : previous.cpu
                    let memory = menuBar.memory ? memoryReader.sample() : previous.memory
                    let thermal = menuBar.temperature ? thermalReader.sample() : previous.thermal
                    let network: NetworkSample
                    if menuBar.network {
                        let rates = networkReader.sample(includeIdentity: false)
                        network = NetworkSample(
                            downloadBytesPerSec: rates.downloadBytesPerSec,
                            uploadBytesPerSec: rates.uploadBytesPerSec,
                            interfaceName: previous.network.interfaceName,
                            localIPAddress: previous.network.localIPAddress,
                            timestamp: rates.timestamp
                        )
                    } else {
                        network = previous.network
                    }
                    let battery = menuBar.battery ? batteryReader.sample() : previous.battery
                    let uptime = menuBar.uptime ? uptimeReader.sample() : previous.uptime

                    await self?.applyIdleSample(
                        cpu: cpu,
                        memory: memory,
                        network: network,
                        battery: battery,
                        thermal: thermal,
                        uptime: uptime
                    )
                }

                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }

    /// Kept for Settings / callers that previously passed an interval; interval now comes from AppSettings.
    public func startSampling(interval: TimeInterval = 2.0) {
        if interval > 0, abs(AppSettings.shared.samplingInterval - interval) > 0.001 {
            AppSettings.shared.samplingInterval = interval
        }
        restartSampling()
    }

    public func stopSampling() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
    }

    @discardableResult
    public func freeUpMemory() -> Bool {
        memoryReader.requestMemoryPurge()
    }

    private func collectAndApplyFullSample(
        cpuReader: CPUReader,
        memoryReader: MemoryReader,
        diskReader: DiskReader,
        networkReader: NetworkReader,
        batteryReader: BatteryReader,
        thermalReader: ThermalReader,
        sensorReader: SensorReader,
        uptimeReader: UptimeReader,
        gpuReader: GPUReader
    ) async {
        let cpu = cpuReader.sample()
        let memory = memoryReader.sample()
        let disk = diskReader.sample(includeIOThroughput: true)
        let network = networkReader.sample(includeIdentity: true)
        let battery = batteryReader.sample()
        let thermal = thermalReader.sample()
        let fan = sensorReader.sampleFans()
        let uptime = uptimeReader.sample()
        let gpu = gpuReader.sample()

        await applyFullSample(
            cpu: cpu,
            memory: memory,
            disk: disk,
            network: network,
            battery: battery,
            thermal: thermal,
            fan: fan,
            uptime: uptime,
            gpu: gpu
        )
    }

    private func applyFullSample(
        cpu: CPUSample,
        memory: MemorySample,
        disk: DiskSample,
        network: NetworkSample,
        battery: BatterySample,
        thermal: ThermalSample,
        fan: FanSample,
        uptime: UptimeSample,
        gpu: GPUSample
    ) {
        appendCPUMemoryNetworkHistories(cpu: cpu, memory: memory, network: network)
        appendHistory(&diskReadHistory, value: disk.readBytesPerSec)
        appendHistory(&diskWriteHistory, value: disk.writeBytesPerSec)
        if let utilization = gpu.utilizationPercent {
            appendHistory(&gpuHistory, value: utilization)
        }

        let displayCPU = smoothedCPU(from: cpu)
        let displayMemory = smoothedMemory(from: memory)

        let snapshot = SystemSnapshot(
            timestamp: Date(),
            cpu: displayCPU,
            memory: displayMemory,
            disk: disk,
            network: network,
            fan: fan,
            thermal: thermal,
            battery: battery,
            uptime: uptime,
            gpu: gpu,
            cpuHistory: cpuHistory,
            cpuUserHistory: cpuUserHistory,
            cpuSystemHistory: cpuSystemHistory,
            memoryHistory: memoryHistory,
            networkDownHistory: networkDownHistory,
            networkUpHistory: networkUpHistory,
            diskReadHistory: diskReadHistory,
            diskWriteHistory: diskWriteHistory,
            gpuHistory: gpuHistory
        )
        currentSnapshot = snapshot
        sampleTick &+= 1
    }

    private func applyIdleSample(
        cpu: CPUSample,
        memory: MemorySample,
        network: NetworkSample,
        battery: BatterySample,
        thermal: ThermalSample,
        uptime: UptimeSample
    ) {
        appendCPUMemoryNetworkHistories(cpu: cpu, memory: memory, network: network)

        let previous = currentSnapshot
        let displayCPU = smoothedCPU(from: cpu)
        let displayMemory = smoothedMemory(from: memory)
        let snapshot = SystemSnapshot(
            timestamp: Date(),
            cpu: displayCPU,
            memory: displayMemory,
            disk: previous.disk,
            network: network,
            fan: previous.fan,
            thermal: thermal,
            battery: battery,
            uptime: uptime,
            gpu: previous.gpu,
            cpuHistory: cpuHistory,
            cpuUserHistory: cpuUserHistory,
            cpuSystemHistory: cpuSystemHistory,
            memoryHistory: memoryHistory,
            networkDownHistory: networkDownHistory,
            networkUpHistory: networkUpHistory,
            diskReadHistory: diskReadHistory,
            diskWriteHistory: diskWriteHistory,
            gpuHistory: gpuHistory
        )
        currentSnapshot = snapshot
        sampleTick &+= 1
    }

    private func smoothedCPU(from cpu: CPUSample) -> CPUSample {
        let total = ema(&smoothedCPUTotal, cpu.totalPercentage)
        let user = ema(&smoothedCPUUser, cpu.userPercentage)
        let system = ema(&smoothedCPUSystem, cpu.systemPercentage)
        let idle = max(0, 100 - total)
        return CPUSample(
            userPercentage: user,
            systemPercentage: system,
            idlePercentage: idle,
            totalPercentage: total,
            chipModel: cpu.chipModel,
            coreCount: cpu.coreCount,
            timestamp: cpu.timestamp
        )
    }

    private func smoothedMemory(from memory: MemorySample) -> MemorySample {
        let percent = ema(&smoothedMemoryPercent, memory.usedPercentage)
        let usedBytes = UInt64((percent / 100.0) * Double(memory.totalBytes))
        return MemorySample(
            usedBytes: min(memory.totalBytes, usedBytes),
            totalBytes: memory.totalBytes,
            freeBytes: memory.totalBytes > usedBytes ? memory.totalBytes - usedBytes : memory.freeBytes,
            compressedBytes: memory.compressedBytes,
            wiredBytes: memory.wiredBytes,
            swapUsedBytes: memory.swapUsedBytes,
            pressureLevel: memory.pressureLevel,
            timestamp: memory.timestamp
        )
    }

    private func ema(_ state: inout Double?, _ sample: Double) -> Double {
        if let previous = state {
            let next = previous + displaySmoothAlpha * (sample - previous)
            state = next
            return next
        }
        state = sample
        return sample
    }

    private func appendCPUMemoryNetworkHistories(cpu: CPUSample, memory: MemorySample, network: NetworkSample) {
        // Graphs keep raw samples; headline / menu-bar numbers are lightly smoothed.
        appendHistory(&cpuHistory, value: cpu.totalPercentage)
        appendHistory(&cpuUserHistory, value: cpu.userPercentage)
        appendHistory(&cpuSystemHistory, value: cpu.systemPercentage)
        appendHistory(&memoryHistory, value: memory.usedPercentage)
        appendHistory(&networkDownHistory, value: network.downloadBytesPerSec)
        appendHistory(&networkUpHistory, value: network.uploadBytesPerSec)

        let networkPeak = max(
            network.downloadBytesPerSec,
            network.uploadBytesPerSec,
            networkDownHistory.max() ?? 0,
            networkUpHistory.max() ?? 0
        )
        networkGraphMaxBytesPerSec = max(102_400, networkPeak * 1.15)
    }

    private func appendHistory(_ array: inout [Double], value: Double) {
        array.append(value)
        if array.count > maxHistoryLength {
            array.removeFirst(array.count - maxHistoryLength)
        }
    }
}

/// Which cheap menu-bar readers to run while the popover is closed.
private struct MenuBarSamplingFlags: Sendable {
    let cpu: Bool
    let memory: Bool
    let temperature: Bool
    let network: Bool
    let battery: Bool
    let uptime: Bool

    var needsAnySample: Bool {
        cpu || memory || temperature || network || battery || uptime
    }

    @MainActor
    init(settings: AppSettings) {
        cpu = settings.showMenuBarCPU
        memory = settings.showMenuBarMemory
        temperature = settings.showMenuBarTemperature
        network = settings.showMenuBarNetwork
        battery = settings.showMenuBarBattery
        uptime = settings.showMenuBarUptime
    }
}
