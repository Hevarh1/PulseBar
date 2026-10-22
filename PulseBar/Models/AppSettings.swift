import Foundation
import Combine
import ServiceManagement

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

    // MARK: - Dashboard Metric Visibility
    // UserDefaults keys keep the historical `show*Card` names so existing prefs migrate.
    @Published public var showDashboardCPU: Bool {
        didSet { defaults.set(showDashboardCPU, forKey: "showCPUCard") }
    }
    @Published public var showDashboardGPU: Bool {
        didSet { defaults.set(showDashboardGPU, forKey: "showGPUCard") }
    }
    @Published public var showDashboardMemory: Bool {
        didSet { defaults.set(showDashboardMemory, forKey: "showMemoryCard") }
    }
    @Published public var showDashboardStorage: Bool {
        didSet { defaults.set(showDashboardStorage, forKey: "showStorageCard") }
    }
    @Published public var showDashboardFan: Bool {
        didSet { defaults.set(showDashboardFan, forKey: "showFanCard") }
    }
    @Published public var showDashboardNetwork: Bool {
        didSet { defaults.set(showDashboardNetwork, forKey: "showNetworkCard") }
    }
    @Published public var showUtilityGrid: Bool {
        didSet { defaults.set(showUtilityGrid, forKey: "showUtilityGrid") }
    }

    // MARK: - Refresh and Display
    /// Sampling rate while the dashboard is open.
    @Published public var samplingInterval: Double {
        didSet { defaults.set(samplingInterval, forKey: "samplingInterval") }
    }
    /// Sampling rate for menu-bar indicators while the dashboard is closed.
    @Published public var menuBarSamplingInterval: Double {
        didSet { defaults.set(menuBarSamplingInterval, forKey: "menuBarSamplingInterval") }
    }
    @Published public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: "temperatureUnitRaw") }
    }
    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    /// Global ⌃⌘P shortcut that shows or hides the dashboard.
    @Published public var dashboardShortcutEnabled: Bool {
        didSet { defaults.set(dashboardShortcutEnabled, forKey: "dashboardShortcutEnabled") }
    }
    /// Periodically ask GitHub Releases for a newer PulseBar.app (install stays optional).
    @Published public var checkForUpdatesAutomatically: Bool {
        didSet { defaults.set(checkForUpdatesAutomatically, forKey: "checkForUpdatesAutomatically") }
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
        if def.object(forKey: "menuBarSamplingInterval") == nil { def.set(1.0, forKey: "menuBarSamplingInterval") }
        if def.object(forKey: "dashboardShortcutEnabled") == nil { def.set(true, forKey: "dashboardShortcutEnabled") }
        if def.object(forKey: "checkForUpdatesAutomatically") == nil { def.set(true, forKey: "checkForUpdatesAutomatically") }

        self.showMenuBarCPU = def.bool(forKey: "showMenuBarCPU")
        self.showMenuBarMemory = def.bool(forKey: "showMenuBarMemory")
        self.showMenuBarTemperature = def.bool(forKey: "showMenuBarTemperature")
        self.showMenuBarNetwork = def.bool(forKey: "showMenuBarNetwork")
        self.showMenuBarBattery = def.bool(forKey: "showMenuBarBattery")
        self.showMenuBarUptime = def.bool(forKey: "showMenuBarUptime")

        self.showDashboardCPU = def.bool(forKey: "showCPUCard")
        self.showDashboardGPU = def.bool(forKey: "showGPUCard")
        self.showDashboardMemory = def.bool(forKey: "showMemoryCard")
        self.showDashboardStorage = def.bool(forKey: "showStorageCard")
        self.showDashboardFan = def.bool(forKey: "showFanCard")
        self.showDashboardNetwork = def.bool(forKey: "showNetworkCard")
        self.showUtilityGrid = def.bool(forKey: "showUtilityGrid")

        self.samplingInterval = def.double(forKey: "samplingInterval") > 0 ? def.double(forKey: "samplingInterval") : 1.0
        self.menuBarSamplingInterval = def.double(forKey: "menuBarSamplingInterval") > 0
            ? def.double(forKey: "menuBarSamplingInterval")
            : 1.0
        let unitRaw = def.string(forKey: "temperatureUnitRaw") ?? TemperatureUnit.celsius.rawValue
        self.temperatureUnit = TemperatureUnit(rawValue: unitRaw) ?? .celsius
        self.launchAtLogin = def.bool(forKey: "launchAtLogin")
        self.dashboardShortcutEnabled = def.bool(forKey: "dashboardShortcutEnabled")
        self.checkForUpdatesAutomatically = def.bool(forKey: "checkForUpdatesAutomatically")

        syncLaunchAtLoginFromSystem()
    }

    /// Align the toggle with `SMAppService` so it stays truthful after System Settings changes.
    public func syncLaunchAtLoginFromSystem() {
        guard #available(macOS 13.0, *) else { return }
        guard isBundledApp else { return }

        let enabled = SMAppService.mainApp.status == .enabled
        if launchAtLogin != enabled {
            launchAtLogin = enabled
        }
    }

    private var isBundledApp: Bool {
        let bundlePath = Bundle.main.bundleURL.path
        return bundlePath.hasSuffix(".app") || bundlePath.contains(".app/")
    }
}
