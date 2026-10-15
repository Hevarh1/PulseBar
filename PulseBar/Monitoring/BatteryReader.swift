import Foundation
import IOKit.ps

public final class BatteryReader: @unchecked Sendable {
    public init() {}

    public func sample() -> BatterySample {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            // Desktop Mac without battery
            return BatterySample(
                percentage: 100,
                isCharging: false,
                isPluggedIn: true,
                powerSource: "AC Power",
                condition: "Normal",
                isPresent: false,
                timestamp: Date()
            )
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let currentCap = description[kIOPSCurrentCapacityKey as String] as? Int ?? 100
            let maxCap = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String ?? ""
            let isPluggedIn = (powerSourceState == (kIOPSACPowerValue as String))
            let condition = description[kIOPSBatteryHealthKey as String] as? String ?? "Normal"

            let percent = maxCap > 0 ? Int((Double(currentCap) / Double(maxCap)) * 100) : currentCap

            return BatterySample(
                percentage: max(0, min(100, percent)),
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                powerSource: isPluggedIn ? "AC Power" : "Battery Power",
                condition: condition,
                isPresent: true,
                timestamp: Date()
            )
        }

        return BatterySample(
            percentage: 100,
            isCharging: false,
            isPluggedIn: true,
            powerSource: "AC Power",
            condition: "Normal",
            isPresent: false,
            timestamp: Date()
        )
    }
}
