import Foundation

public struct SystemSnapshot: Sendable {
    public let timestamp: Date
    public let cpu: CPUSample
    public let memory: MemorySample
    public let disk: DiskSample
    public let network: NetworkSample
    public let fan: FanSample
    public let thermal: ThermalSample
    public let battery: BatterySample
    public let uptime: UptimeSample
    public let gpu: GPUSample

    public let cpuHistory: [Double]
    public let cpuUserHistory: [Double]
    public let cpuSystemHistory: [Double]
    public let memoryHistory: [Double]
    public let networkDownHistory: [Double]
    public let networkUpHistory: [Double]
    public let diskReadHistory: [Double]
    public let diskWriteHistory: [Double]

    public init(
        timestamp: Date = Date(),
        cpu: CPUSample = CPUSample(),
        memory: MemorySample = MemorySample(),
        disk: DiskSample = DiskSample(),
        network: NetworkSample = NetworkSample(),
        fan: FanSample = FanSample(),
        thermal: ThermalSample = ThermalSample(),
        battery: BatterySample = BatterySample(),
        uptime: UptimeSample = UptimeSample(),
        gpu: GPUSample = GPUSample(),
        cpuHistory: [Double] = [],
        cpuUserHistory: [Double] = [],
        cpuSystemHistory: [Double] = [],
        memoryHistory: [Double] = [],
        networkDownHistory: [Double] = [],
        networkUpHistory: [Double] = [],
        diskReadHistory: [Double] = [],
        diskWriteHistory: [Double] = []
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.fan = fan
        self.thermal = thermal
        self.battery = battery
        self.uptime = uptime
        self.gpu = gpu
        self.cpuHistory = cpuHistory
        self.cpuUserHistory = cpuUserHistory
        self.cpuSystemHistory = cpuSystemHistory
        self.memoryHistory = memoryHistory
        self.networkDownHistory = networkDownHistory
        self.networkUpHistory = networkUpHistory
        self.diskReadHistory = diskReadHistory
        self.diskWriteHistory = diskWriteHistory
    }

    public static let empty = SystemSnapshot()
}
