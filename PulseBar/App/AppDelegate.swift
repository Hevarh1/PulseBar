import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = MetricsCoordinator.shared
        menuBarController = MenuBarController()
        AppUpdater.shared.scheduleAutomaticCheckIfNeeded()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        PowerController.shared.disableKeepAwake()
        MetricsCoordinator.shared.stopSampling()
    }
}
