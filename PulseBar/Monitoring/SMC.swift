import Foundation
import IOKit

/// A read-only connection to the System Management Controller (AppleSMC).
/// Shared by the temperature and fan readers; calls are serialised.
final class SMCConnection: @unchecked Sendable {
    static let shared = SMCConnection()

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

    private static let readKeyInfo: UInt8 = 9
    private static let readBytes: UInt8 = 5

    private var connection: io_connect_t = 0
    private let lock = NSLock()

    var isAvailable: Bool { connection != 0 }

    private init() {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &iterator) == KERN_SUCCESS else {
            return
        }
        let service = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard service != 0 else { return }
        var conn: io_connect_t = 0
        if IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS {
            connection = conn
        }
        IOObjectRelease(service)
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    /// Reads a key and decodes it to a number, or nil when the key is missing
    /// or its data type isn't one `SMCValue` understands.
    func number(_ key: String) -> Double? {
        guard let raw = read(key) else { return nil }
        return SMCValue.decode(type: raw.type, bytes: raw.bytes)
    }

    /// Raw read: the key's four-character data type and its bytes.
    func read(_ key: String) -> (type: String, bytes: [UInt8])? {
        guard connection != 0, let code = SMCValue.fourCC(key) else { return nil }
        lock.lock()
        defer { lock.unlock() }

        var infoIn = SMCKeyData()
        infoIn.key = code
        infoIn.data8 = Self.readKeyInfo
        guard let info = call(&infoIn), info.result == 0, info.dataSize > 0, info.dataSize <= 32 else {
            return nil
        }

        var readIn = SMCKeyData()
        readIn.key = code
        readIn.dataSize = info.dataSize
        readIn.data8 = Self.readBytes
        guard let read = call(&readIn), read.result == 0 else { return nil }

        let all = withUnsafeBytes(of: read.bytes) { Array($0) }
        return (SMCValue.typeString(info.dataType), Array(all.prefix(Int(info.dataSize))))
    }

    private func call(_ input: inout SMCKeyData) -> SMCKeyData? {
        var output = SMCKeyData()
        let inSize = MemoryLayout<SMCKeyData>.stride
        var outSize = inSize
        let kr = withUnsafeMutablePointer(to: &input) { inPtr in
            withUnsafeMutablePointer(to: &output) { outPtr in
                IOConnectCallStructMethod(connection, 2, inPtr, inSize, outPtr, &outSize)
            }
        }
        return kr == KERN_SUCCESS ? output : nil
    }
}

/// Decoding for the SMC data types PulseBar reads.
enum SMCValue {
    static func fourCC(_ string: String) -> UInt32? {
        let bytes = Array(string.utf8)
        guard bytes.count == 4 else { return nil }
        return bytes.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    static func typeString(_ type: UInt32) -> String {
        let chars = [24, 16, 8, 0].map { UInt8((type >> UInt32($0)) & 0xff) }
        return String(bytes: chars, encoding: .ascii) ?? ""
    }

    /// - `flt `: 32-bit float, little-endian (Apple Silicon).
    /// - `fpe2`: unsigned 14.2 fixed point, big-endian (Intel fan speeds).
    /// - `sp78`: signed 8.8 fixed point, big-endian (Intel temperatures).
    /// - `ui8 ` / `ui16` / `ui32`: unsigned integers, big-endian.
    static func decode(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            let value = Double(Float(bitPattern: bits))
            return value.isFinite ? value : nil
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case "ui8 ":
            guard bytes.count >= 1 else { return nil }
            return Double(bytes[0])
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
        default:
            return nil
        }
    }
}
