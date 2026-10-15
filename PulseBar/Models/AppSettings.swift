import Foundation
import Combine

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Menu Bar Indicators
    @Published public var showMenuBarCPU: Bool {
        didSet { defaults.set(showMenuBarCPU, forKey: "showMenuBarCPU") }
    }
    @Published public var showMenuBarMemory: Bool {
        didSet { defaults.set(showMenuBarMemory, forKey: "showMenuBarMemory") }
    }
    @Published public var showMenuBarTemperature: Bool {
        didSet { defaults.set(showMenuBarTemperature, forKey: "showMenuBarTemperature") }
    }
    @Published public var showMenuBarNetwork: Bool {
        didSet { defaults.set(showMenuBarNetwork, forKey: "showMenuBarNetwork") }
    }
    @Published public var showMenuBarBattery: Bool {
        didSet { defaults.set(showMenuBarBattery, forKey: "showMenuBarBattery") }
    }
    @Published public var showMenuBarUptime: Bool {
        didSet { defaults.set(showMenuBarUptime, forKey: "showMenuBarUptime") }
    }

    // MARK: - Dashboard Card Visibility
    @Published public var showCPUCard: Bool {
        didSet { defaults.set(showCPUCard, forKey: "showCPUCard") }
    }
    @Published public var showGPUCard: Bool {
        didSet { defaults.set(showGPUCard, forKey: "showGPUCard") }
    }
    @Published public var showMemoryCard: Bool {
        didSet { defaults.set(showMemoryCard, forKey: "showMemoryCard") }
    }
    @Published public var showStorageCard: Bool {
        didSet { defaults.set(showStorageCard, forKey: "showStorageCard") }
    }
    @Published public var showFanCard: Bool {
        didSet { defaults.set(showFanCard, forKey: "showFanCard") }
    }
    @Published public var showNetworkCard: Bool {
        didSet { defaults.set(showNetworkCard, forKey: "showNetworkCard") }
    }
    @Published public var showUtilityGrid: Bool {
        didSet { defaults.set(showUtilityGrid, forKey: "showUtilityGrid") }
    }

    // MARK: - Refresh and Display
    @Published public var samplingInterval: Double {
        didSet { defaults.set(samplingInterval, forKey: "samplingInterval") }
    }
    @Published public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: "temperatureUnitRaw") }
    }
    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    private init() {
        // Register default values if not yet set
        let def = UserDefaults.standard
        if def.object(forKey: "showMenuBarCPU") == nil { def.set(true, forKey: "showMenuBarCPU") }
        if def.object(forKey: "showMenuBarMemory") == nil { def.set(true, forKey: "showMenuBarMemory") }
        if def.object(forKey: "showMenuBarTemperature") == nil { def.set(true, forKey: "showMenuBarTemperature") }
        if def.object(forKey: "showCPUCard") == nil { def.set(true, forKey: "showCPUCard") }
        if def.object(forKey: "showGPUCard") == nil { def.set(true, forKey: "showGPUCard") }
        if def.object(forKey: "showMemoryCard") == nil { def.set(true, forKey: "showMemoryCard") }
        if def.object(forKey: "showStorageCard") == nil { def.set(true, forKey: "showStorageCard") }
        if def.object(forKey: "showFanCard") == nil { def.set(true, forKey: "showFanCard") }
        if def.object(forKey: "showNetworkCard") == nil { def.set(true, forKey: "showNetworkCard") }
        if def.object(forKey: "showUtilityGrid") == nil { def.set(true, forKey: "showUtilityGrid") }
        if def.object(forKey: "samplingInterval") == nil { def.set(1.0, forKey: "samplingInterval") }

        self.showMenuBarCPU = def.bool(forKey: "showMenuBarCPU")
        self.showMenuBarMemory = def.bool(forKey: "showMenuBarMemory")
        self.showMenuBarTemperature = def.bool(forKey: "showMenuBarTemperature")
        self.showMenuBarNetwork = def.bool(forKey: "showMenuBarNetwork")
        self.showMenuBarBattery = def.bool(forKey: "showMenuBarBattery")
        self.showMenuBarUptime = def.bool(forKey: "showMenuBarUptime")

        self.showCPUCard = def.bool(forKey: "showCPUCard")
        self.showGPUCard = def.bool(forKey: "showGPUCard")
        self.showMemoryCard = def.bool(forKey: "showMemoryCard")
        self.showStorageCard = def.bool(forKey: "showStorageCard")
        self.showFanCard = def.bool(forKey: "showFanCard")
        self.showNetworkCard = def.bool(forKey: "showNetworkCard")
        self.showUtilityGrid = def.bool(forKey: "showUtilityGrid")

        self.samplingInterval = def.double(forKey: "samplingInterval") > 0 ? def.double(forKey: "samplingInterval") : 1.0
        let unitRaw = def.string(forKey: "temperatureUnitRaw") ?? TemperatureUnit.celsius.rawValue
        self.temperatureUnit = TemperatureUnit(rawValue: unitRaw) ?? .celsius
        self.launchAtLogin = def.bool(forKey: "launchAtLogin")
    }
}
