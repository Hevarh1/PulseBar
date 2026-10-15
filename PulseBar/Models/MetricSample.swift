import Foundation

public enum MemoryPressureLevel: String, Codable, Sendable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"

    public var colorName: String {
        switch self {
        case .normal: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        }
    }
}

public enum ThermalStateLevel: String, Codable, Sendable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    public var statusDescription: String {
        switch self {
        case .nominal: return "Cool & Healthy"
        case .fair: return "Elevated Load"
        case .serious: return "Heavy Throttling Risk"
        case .critical: return "Thermal Throttling Active"
        }
    }
}

public struct CPUSample: Identifiable, Sendable {
    public let id = UUID()
    public let userPercentage: Double
    public let systemPercentage: Double
    public let idlePercentage: Double
    public let totalPercentage: Double
    public let chipModel: String
    public let coreCount: Int
    public let timestamp: Date

    public init(
        userPercentage: Double = 0,
        systemPercentage: Double = 0,
        idlePercentage: Double = 100,
        totalPercentage: Double = 0,
        chipModel: String = "Apple Silicon",
        coreCount: Int = 8,
        timestamp: Date = Date()
    ) {
        self.userPercentage = userPercentage
        self.systemPercentage = systemPercentage
        self.idlePercentage = idlePercentage
        self.totalPercentage = totalPercentage
        self.chipModel = chipModel
        self.coreCount = coreCount
        self.timestamp = timestamp
    }
}

public struct MemorySample: Identifiable, Sendable {
    public let id = UUID()
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let freeBytes: UInt64
    public let compressedBytes: UInt64
    public let wiredBytes: UInt64
    public let swapUsedBytes: UInt64
    public let pressureLevel: MemoryPressureLevel
    public let timestamp: Date

    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }

    public init(
        usedBytes: UInt64 = 0,
        totalBytes: UInt64 = 16 * 1024 * 1024 * 1024,
        freeBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        wiredBytes: UInt64 = 0,
        swapUsedBytes: UInt64 = 0,
        pressureLevel: MemoryPressureLevel = .normal,
        timestamp: Date = Date()
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.compressedBytes = compressedBytes
        self.wiredBytes = wiredBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressureLevel = pressureLevel
        self.timestamp = timestamp
    }
}

public struct DiskSample: Identifiable, Sendable {
    public let id = UUID()
    public let volumeName: String
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let freeBytes: UInt64
    public let readBytesPerSec: Double
    public let writeBytesPerSec: Double
    public let isBootVolume: Bool
    public let timestamp: Date

    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }

    public init(
        volumeName: String = "Macintosh HD",
        usedBytes: UInt64 = 0,
        totalBytes: UInt64 = 1,
        freeBytes: UInt64 = 0,
        readBytesPerSec: Double = 0,
        writeBytesPerSec: Double = 0,
        isBootVolume: Bool = true,
        timestamp: Date = Date()
    ) {
        self.volumeName = volumeName
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.readBytesPerSec = readBytesPerSec
        self.writeBytesPerSec = writeBytesPerSec
        self.isBootVolume = isBootVolume
        self.timestamp = timestamp
    }
}

public struct NetworkSample: Identifiable, Sendable {
    public let id = UUID()
    public let downloadBytesPerSec: Double
    public let uploadBytesPerSec: Double
    public let interfaceName: String
    public let localIPAddress: String
    public let timestamp: Date

    public init(
        downloadBytesPerSec: Double = 0,
        uploadBytesPerSec: Double = 0,
        interfaceName: String = "Wi-Fi",
        localIPAddress: String = "127.0.0.1",
        timestamp: Date = Date()
    ) {
        self.downloadBytesPerSec = downloadBytesPerSec
        self.uploadBytesPerSec = uploadBytesPerSec
        self.interfaceName = interfaceName
        self.localIPAddress = localIPAddress
        self.timestamp = timestamp
    }
}

public struct FanSample: Identifiable, Sendable {
    public let id = UUID()
    public let fanCount: Int
    public let fanSpeeds: [Double]
    public let isFanless: Bool
    public let statusDescription: String
    public let timestamp: Date

    public init(
        fanCount: Int = 0,
        fanSpeeds: [Double] = [],
        isFanless: Bool = true,
        statusDescription: String = "No fan detected",
        timestamp: Date = Date()
    ) {
        self.fanCount = fanCount
        self.fanSpeeds = fanSpeeds
        self.isFanless = isFanless
        self.statusDescription = statusDescription
        self.timestamp = timestamp
    }
}

public struct ThermalSample: Identifiable, Sendable {
    public let id = UUID()
    public let thermalState: ThermalStateLevel
    public let temperatureCelsius: Double?
    public let isAvailable: Bool
    public let label: String
    public let timestamp: Date

    public init(
        thermalState: ThermalStateLevel = .nominal,
        temperatureCelsius: Double? = nil,
        isAvailable: Bool = true,
        label: String = "Thermal State",
        timestamp: Date = Date()
    ) {
        self.thermalState = thermalState
        self.temperatureCelsius = temperatureCelsius
        self.isAvailable = isAvailable
        self.label = label
        self.timestamp = timestamp
    }
}

public struct BatterySample: Identifiable, Sendable {
    public let id = UUID()
    public let percentage: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let powerSource: String
    public let condition: String
    public let isPresent: Bool
    public let timestamp: Date

    public init(
        percentage: Int = 100,
        isCharging: Bool = false,
        isPluggedIn: Bool = true,
        powerSource: String = "AC Power",
        condition: String = "Normal",
        isPresent: Bool = true,
        timestamp: Date = Date()
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.powerSource = powerSource
        self.condition = condition
        self.isPresent = isPresent
        self.timestamp = timestamp
    }
}

public struct UptimeSample: Identifiable, Sendable {
    public let id = UUID()
    public let bootTime: Date
    public let uptimeSeconds: TimeInterval
    public let timestamp: Date

    public init(
        bootTime: Date = Date(),
        uptimeSeconds: TimeInterval = 0,
        timestamp: Date = Date()
    ) {
        self.bootTime = bootTime
        self.uptimeSeconds = uptimeSeconds
        self.timestamp = timestamp
    }
}

public struct GPUSample: Identifiable, Sendable {
    public let id = UUID()
    public let modelName: String
    public let coreCount: Int?
    public let isAvailable: Bool
    public let utilizationPercent: Double?
    public let timestamp: Date

    public init(
        modelName: String = "Apple M-Series GPU",
        coreCount: Int? = nil,
        isAvailable: Bool = true,
        utilizationPercent: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.modelName = modelName
        self.coreCount = coreCount
        self.isAvailable = isAvailable
        self.utilizationPercent = utilizationPercent
        self.timestamp = timestamp
    }
}
