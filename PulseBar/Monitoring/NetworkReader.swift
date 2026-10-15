import Foundation
import Darwin

public final class NetworkReader: @unchecked Sendable {
    private var lastSampleTime: Date?
    private var lastInBytes: UInt64?
    private var lastOutBytes: UInt64?

    /// True after at least one counter read (rate baselines exist).
    var hasSamplingBaseline: Bool { lastSampleTime != nil }

    public init() {}

    /// Local IPv4 of the primary up non-loopback interface, if any.
    /// Used by clipboard helpers; never looks up a public IP.
    public func primaryLocalIPAddress() -> String? {
        let state = readInterfaceState(includeIdentity: true)
        guard state.localIP != "Unavailable", !state.localIP.isEmpty else { return nil }
        return state.localIP
    }

    /// Samples interface byte counters. When `includeIdentity` is false, skips primary
    /// interface name / local IP resolution (idle menu-bar path only needs rates).
    public func sample(includeIdentity: Bool = true) -> NetworkSample {
        let now = Date()
        let counters = readInterfaceState(includeIdentity: includeIdentity)

        var downRate: Double = 0
        var upRate: Double = 0

        if let lastTime = lastSampleTime,
           let lastIn = lastInBytes,
           let lastOut = lastOutBytes {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed > 0 {
                let inDelta = counters.inBytes >= lastIn ? Double(counters.inBytes - lastIn) : 0
                let outDelta = counters.outBytes >= lastOut ? Double(counters.outBytes - lastOut) : 0
                downRate = inDelta / elapsed
                upRate = outDelta / elapsed
            }
        }

        lastSampleTime = now
        lastInBytes = counters.inBytes
        lastOutBytes = counters.outBytes

        return NetworkSample(
            downloadBytesPerSec: downRate,
            uploadBytesPerSec: upRate,
            interfaceName: counters.interfaceName,
            localIPAddress: counters.localIP,
            timestamp: now
        )
    }

    private struct InterfaceState {
        var inBytes: UInt64 = 0
        var outBytes: UInt64 = 0
        var interfaceName: String = "Wi-Fi"
        var localIP: String = "Unavailable"
    }

    /// Single `getifaddrs` walk for counters and optional IPv4 identity.
    private func readInterfaceState(includeIdentity: Bool) -> InterfaceState {
        var result = InterfaceState()
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else {
            return result
        }
        defer { freeifaddrs(ifap) }

        var foundIP = false
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cur {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            let family = ptr.pointee.ifa_addr?.pointee.sa_family

            if family == UInt8(AF_LINK) && isUp && !isLoopback {
                let data = unsafeBitCast(ptr.pointee.ifa_data, to: UnsafeMutablePointer<if_data>?.self)
                if let d = data?.pointee {
                    result.inBytes += UInt64(d.ifi_ibytes)
                    result.outBytes += UInt64(d.ifi_obytes)
                }
            }

            if includeIdentity, !foundIP,
               family == UInt8(AF_INET), isUp, !isLoopback {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    ptr.pointee.ifa_addr,
                    socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    let ipStr = String(cString: hostname)
                    let ifName = String(cString: ptr.pointee.ifa_name)
                    if !ipStr.isEmpty && ipStr != "127.0.0.1" {
                        result.localIP = ipStr
                        result.interfaceName = ifName.starts(with: "en0")
                            ? "Wi-Fi"
                            : (ifName.starts(with: "en") ? "Ethernet (\(ifName))" : ifName)
                        foundIP = true
                    }
                }
            }

            cur = ptr.pointee.ifa_next
        }

        return result
    }
}
