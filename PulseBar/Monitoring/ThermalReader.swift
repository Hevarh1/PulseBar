import Foundation
import Darwin
import IOKit

public final class ThermalReader: @unchecked Sendable {
    // MARK: - HID (fallback)

    private typealias IOHIDEventSystemClientCreateType = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias IOHIDEventSystemClientSetMatchingType = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias IOHIDEventSystemClientCopyServicesType = @convention(c) (AnyObject) -> CFArray?
    private typealias IOHIDServiceClientCopyEventWithType = @convention(c) (AnyObject, Int64, Int32, Int64) -> AnyObject?
    private typealias IOHIDEventGetFloatValueType = @convention(c) (AnyObject, Int32) -> Double
    private typealias IOHIDServiceClientCopyPropertyType = @convention(c) (AnyObject, CFString) -> Unmanaged<CFTypeRef>?

    private var hidClient: AnyObject?
    private var copyServicesFn: IOHIDEventSystemClientCopyServicesType?
    private var copyEventFn: IOHIDServiceClientCopyEventWithType?
    private var getFloatFn: IOHIDEventGetFloatValueType?
    private var copyPropertyFn: IOHIDServiceClientCopyPropertyType?

    private var cachedHIDServices: [AnyObject]?
    private var hidServicesCacheTime: Date?
    private let hidServicesCacheTTL: TimeInterval = 60.0

    // MARK: - AppleSMC

    /// 80-byte SMCKeyData layout: `data8` at offset 42, `result` at 40, `bytes` at 48.
    /// Empirically required by AppleSMC's user client on Apple Silicon.
    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0)
        var versPad: (UInt8, UInt8) = (0, 0)
        var pLimitVersion: UInt16 = 0
        var pLimitLength: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
        var keyInfoPad: (UInt8, UInt8, UInt8) = (0, 0, 0)
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data8Pad: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        ) = (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    private static let smcKeyInfo: UInt8 = 9
    private static let smcReadKey: UInt8 = 5

    /// Chip-family CPU package key sets (not a union of every model).
    /// Select one family table; mixing them and taking the global max over-reads
    /// (e.g. `Tp0f` / `Tp0E` sit well above the typical package cluster).
    private static let cpuTemperatureKeySets: [[String]] = [
        ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"],
        ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"],
        ["Tp00", "Tp04", "Tp0C", "Tp0G", "Tp0O", "Tp0R", "Tp0X", "Tp0a", "Tp0p", "Tp0y"],
        ["Tp0K", "Tp0U", "Tp0X", "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"],
        ["Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"],
        ["Tp0G", "Tp0F", "Tp0E", "Tp0D"]
    ]

    /// Cached per-machine key set (whichever family table has the most readable keys).
    private var selectedCPUTemperatureKeys: [String]?

    private var smcConnection: io_connect_t = 0
    private var smcAvailable: Bool = false

    public init() {
        setupSMC()
        setupHIDClient()
    }

    deinit {
        if smcConnection != 0 {
            IOServiceClose(smcConnection)
            smcConnection = 0
        }
    }

    public func sample() -> ThermalSample {
        let state = ProcessInfo.processInfo.thermalState
        let level: ThermalStateLevel
        switch state {
        case .nominal: level = .nominal
        case .fair: level = .fair
        case .serious: level = .serious
        case .critical: level = .critical
        @unknown default: level = .nominal
        }

        // Prefer AppleSMC Tp* package keys over HID die averages.
        // HID die sensors under-read vs SMC by ~10–15°C on Apple Silicon.
        let liveTemp = readSMCTemperature() ?? readHIDDieTemperature()

        return ThermalSample(
            thermalState: level,
            temperatureCelsius: liveTemp,
            isAvailable: liveTemp != nil,
            label: liveTemp != nil ? "CPU Temperature" : "Thermal State",
            timestamp: Date()
        )
    }

    // MARK: - SMC

    private func setupSMC() {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &iterator) == KERN_SUCCESS else {
            return
        }
        let service = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard service != 0 else { return }
        var conn: io_connect_t = 0
        let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)
        guard kr == KERN_SUCCESS else { return }
        smcConnection = conn
        smcAvailable = true
    }

    private static func fourCC(_ string: String) -> UInt32 {
        let bytes = Array(string.utf8)
        guard bytes.count == 4 else { return 0 }
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }

    private static func typeFourCC(_ type: UInt32) -> String {
        let chars: [UInt8] = [
            UInt8((type >> 24) & 0xff),
            UInt8((type >> 16) & 0xff),
            UInt8((type >> 8) & 0xff),
            UInt8(type & 0xff)
        ]
        return String(bytes: chars, encoding: .ascii) ?? ""
    }

    private func smcCall(_ input: inout SMCKeyData) -> SMCKeyData? {
        guard smcConnection != 0 else { return nil }
        var output = SMCKeyData()
        let inSize = MemoryLayout<SMCKeyData>.stride
        var outSize = inSize
        let kr = withUnsafeMutablePointer(to: &input) { inPtr in
            withUnsafeMutablePointer(to: &output) { outPtr in
                IOConnectCallStructMethod(smcConnection, 2, inPtr, inSize, outPtr, &outSize)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        return output
    }

    private func smcReadTemperature(key: String) -> Double? {
        var infoIn = SMCKeyData()
        infoIn.key = Self.fourCC(key)
        infoIn.data8 = Self.smcKeyInfo
        guard let info = smcCall(&infoIn), info.result == 0, info.dataSize > 0, info.dataSize <= 32 else {
            return nil
        }

        var readIn = SMCKeyData()
        readIn.key = Self.fourCC(key)
        readIn.dataSize = info.dataSize
        readIn.data8 = Self.smcReadKey
        guard let read = smcCall(&readIn), read.result == 0 else {
            return nil
        }

        let type = Self.typeFourCC(info.dataType)
        let byteTuple = read.bytes
        let bytes: [UInt8] = [
            byteTuple.0, byteTuple.1, byteTuple.2, byteTuple.3,
            byteTuple.4, byteTuple.5, byteTuple.6, byteTuple.7
        ]

        let value: Double?
        if type == "flt " {
            var floatValue: Float = 0
            _ = bytes.withUnsafeBytes { raw in
                memcpy(&floatValue, raw.baseAddress!, 4)
            }
            value = Double(floatValue)
        } else if type == "sp78" {
            let raw = (Int16(bytes[0]) << 8) | Int16(bytes[1])
            value = Double(raw) / 256.0
        } else {
            value = nil
        }

        guard let temp = value, temp > 5, temp < 130 else { return nil }
        return temp
    }

    private func resolveCPUTemperatureKeys() -> [String] {
        if let selected = selectedCPUTemperatureKeys {
            return selected
        }

        var bestKeys: [String] = []
        var bestCount = 0
        for keySet in Self.cpuTemperatureKeySets {
            let readable = keySet.filter { smcReadTemperature(key: $0) != nil }
            if readable.count > bestCount {
                bestCount = readable.count
                bestKeys = readable
            }
        }

        // Last resort: any Tp* candidates that respond on this Mac.
        if bestKeys.isEmpty {
            let fallback = Array(Set(Self.cpuTemperatureKeySets.flatMap { $0 })).sorted()
            bestKeys = fallback.filter { smcReadTemperature(key: $0) != nil }
        }

        selectedCPUTemperatureKeys = bestKeys
        return bestKeys
    }

    /// CPU package temperature: mean of the active chip's `Tp*` set.
    private func readSMCTemperature() -> Double? {
        guard smcAvailable else { return nil }
        let keys = resolveCPUTemperatureKeys()
        guard !keys.isEmpty else { return nil }

        var temps: [Double] = []
        temps.reserveCapacity(keys.count)
        for key in keys {
            if let temp = smcReadTemperature(key: key) {
                temps.append(temp)
            }
        }
        guard !temps.isEmpty else { return nil }
        return temps.reduce(0, +) / Double(temps.count)
    }

    // MARK: - HID fallback

    private func setupHIDClient() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return }
        guard let clientCreate = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let clientSetMatching = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let copyServices = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let copyEvent = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let getFloat = dlsym(handle, "IOHIDEventGetFloatValue"),
              let copyProperty = dlsym(handle, "IOHIDServiceClientCopyProperty") else {
            return
        }

        let createFn = unsafeBitCast(clientCreate, to: IOHIDEventSystemClientCreateType.self)
        let setMatchingFn = unsafeBitCast(clientSetMatching, to: IOHIDEventSystemClientSetMatchingType.self)
        self.copyServicesFn = unsafeBitCast(copyServices, to: IOHIDEventSystemClientCopyServicesType.self)
        self.copyEventFn = unsafeBitCast(copyEvent, to: IOHIDServiceClientCopyEventWithType.self)
        self.getFloatFn = unsafeBitCast(getFloat, to: IOHIDEventGetFloatValueType.self)
        self.copyPropertyFn = unsafeBitCast(copyProperty, to: IOHIDServiceClientCopyPropertyType.self)

        if let created = createFn(kCFAllocatorDefault)?.takeRetainedValue() {
            self.hidClient = created
            setMatchingFn(created, [
                "PrimaryUsagePage": 65280,
                "PrimaryUsage": 5
            ] as CFDictionary)
        }
    }

    private func hidServices() -> [AnyObject] {
        if let cached = cachedHIDServices,
           let cachedAt = hidServicesCacheTime,
           Date().timeIntervalSince(cachedAt) < hidServicesCacheTTL {
            return cached
        }
        guard let client = hidClient,
              let copyServices = copyServicesFn,
              let services = copyServices(client) as? [AnyObject] else {
            cachedHIDServices = []
            hidServicesCacheTime = Date()
            return []
        }
        cachedHIDServices = services
        hidServicesCacheTime = Date()
        return services
    }

    private func productName(for service: AnyObject) -> String {
        guard let copyProperty = copyPropertyFn,
              let value = copyProperty(service, "Product" as CFString)?.takeUnretainedValue() as? String else {
            return ""
        }
        return value
    }

    private func readHIDDieTemperature() -> Double? {
        guard let copyEvent = copyEventFn, let getFloat = getFloatFn else { return nil }
        var dieTemps: [Double] = []
        for service in hidServices() {
            guard let event = copyEvent(service, 15, 0, 0) else { continue }
            let temp = getFloat(event, 15 << 16)
            guard temp > 15, temp < 115 else { continue }
            let name = productName(for: service).lowercased()
            if name.contains("tdie") && !name.contains("tcal") {
                dieTemps.append(temp)
            }
        }
        return dieTemps.max()
    }
}
