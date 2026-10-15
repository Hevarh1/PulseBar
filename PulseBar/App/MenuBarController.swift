import AppKit
import SwiftUI
import Combine

@MainActor
public final class MenuBarController: NSObject, NSPopoverDelegate {
    /// One `NSStatusItem` per metric (temperature, memory, CPU, …).
    private var statusItems: [MenuBarMetricKind: NSStatusItem] = [:]
    private var fallbackItem: NSStatusItem?
    /// macOS 26+: tiles float over the desktop in a transparent panel.
    private var panel: DashboardPanel?
    /// macOS 14–15: classic popover.
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var lastSignatures: [MenuBarMetricKind: String] = [:]
    private var lastKindOrder: [MenuBarMetricKind] = []

    public override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeDashboardIfShown),
            name: .pulseBarCloseDashboard,
            object: nil
        )
        if LiquidGlass.isAvailable {
            setupPanel()
        } else {
            setupPopover()
        }
        DashboardShortcut.shared.onPress = { [weak self] in
            self?.toggleDashboard(anchor: nil)
        }
        rebuild(
            kinds: MenuBarRenderer.enabledKinds(
                settings: AppSettings.shared,
                snapshot: MetricsCoordinator.shared.currentSnapshot
            ),
            snapshot: MetricsCoordinator.shared.currentSnapshot,
            force: true
        )
        observeSnapshot()
    }

    private func setupPanel() {
        let panel = DashboardPanel()
        panel.onClose = {
            MetricsCoordinator.shared.setDashboardVisible(false)
        }
        self.panel = panel
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: DesignTokens.popoverWidth, height: DesignTokens.popoverHeight)
        pop.behavior = .transient
        pop.animates = true
        pop.delegate = self
        self.popover = pop
    }

    private func observeSnapshot() {
        MetricsCoordinator.shared.$currentSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.refresh(snapshot: snapshot)
            }
            .store(in: &cancellables)

        // Emits the stored value on subscribe, so this also registers at launch.
        AppSettings.shared.$dashboardShortcutEnabled
            .removeDuplicates()
            .sink { enabled in
                DashboardShortcut.shared.setEnabled(enabled)
            }
            .store(in: &cancellables)

        AppSettings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refresh(
                        snapshot: MetricsCoordinator.shared.currentSnapshot,
                        force: true
                    )
                }
            }
            .store(in: &cancellables)
    }

    private func refresh(snapshot: SystemSnapshot, force: Bool = false) {
        let kinds = MenuBarRenderer.enabledKinds(settings: AppSettings.shared, snapshot: snapshot)
        if force || kinds != lastKindOrder {
            rebuild(kinds: kinds, snapshot: snapshot, force: true)
            return
        }
        for kind in kinds {
            update(kind: kind, snapshot: snapshot, force: force)
        }
    }

    private func rebuild(kinds: [MenuBarMetricKind], snapshot: SystemSnapshot, force: Bool) {
        for kind in statusItems.keys where !kinds.contains(kind) {
            if let item = statusItems.removeValue(forKey: kind) {
                NSStatusBar.system.removeStatusItem(item)
            }
            lastSignatures.removeValue(forKey: kind)
        }

        if !kinds.isEmpty, let fallback = fallbackItem {
            NSStatusBar.system.removeStatusItem(fallback)
            fallbackItem = nil
        }

        // Create last→first so left-to-right order is TEM · MEM · CPU.
        for kind in kinds.reversed() {
            if statusItems[kind] == nil {
                // Fixed width — prevents the bar from jiggling as digits change.
                let item = NSStatusBar.system.statusItem(withLength: MenuBarRenderer.itemWidth)
                if let button = item.button {
                    button.target = self
                    button.action = #selector(statusItemClicked(_:))
                    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                    button.title = ""
                    button.imagePosition = .imageOnly
                    button.imageScaling = .scaleNone
                    button.toolTip = "PulseBar — \(kind.shortLabel)"
                    button.identifier = NSUserInterfaceItemIdentifier(kind.rawValue)
                }
                statusItems[kind] = item
            }
        }

        lastKindOrder = kinds

        if kinds.isEmpty {
            // Icon-only fallback when every metric is hidden in settings.
            if fallbackItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if let button = item.button {
                    button.target = self
                    button.action = #selector(statusItemClicked(_:))
                    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                    button.image = AppIcon.menuBarTemplateImage()
                    button.imagePosition = .imageOnly
                    button.toolTip = "PulseBar"
                    button.title = ""
                }
                fallbackItem = item
            }
        } else {
            for kind in kinds {
                update(kind: kind, snapshot: snapshot, force: force)
            }
        }
    }

    private func update(kind: MenuBarMetricKind, snapshot: SystemSnapshot, force: Bool) {
        guard let item = statusItems[kind] else { return }
        let settings = AppSettings.shared
        let signature = MenuBarRenderer.signature(kind: kind, snapshot: snapshot, settings: settings)
        guard force || lastSignatures[kind] != signature else { return }
        lastSignatures[kind] = signature

        item.button?.image = MetricStatusImage.make(
            value: MenuBarRenderer.displayValue(for: kind, snapshot: snapshot, settings: settings),
            label: kind.shortLabel
        )
        item.button?.toolTip = MenuBarRenderer.accessibilityDescription(
            kind: kind,
            snapshot: snapshot,
            settings: settings
        )
        // The value text fields are hidden from accessibility, so name the button.
        item.button?.setAccessibilityLabel(
            "PulseBar, \(kind.spokenName) \(MenuBarRenderer.displayValue(for: kind, snapshot: snapshot, settings: settings))"
        )
    }

    private var isDashboardShown: Bool {
        panel?.isShown ?? popover?.isShown ?? false
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        toggleDashboard(anchor: sender)
    }

    /// Status-item click or the global shortcut (`anchor` is nil then).
    private func toggleDashboard(anchor: NSStatusBarButton?) {
        if isDashboardShown {
            closeDashboard(anchor, restoringFocus: true)
            return
        }
        // Status items stay clickable during runModal(). If a PulseBar alert
        // (Empty Trash, Eject, errors) is up, surface it instead of opening a
        // dashboard over it that can't be clicked.
        if let modal = NSApp.modalWindow {
            NSApp.activate(ignoringOtherApps: true)
            modal.makeKeyAndOrderFront(nil)
            return
        }
        guard let button = anchor ?? shortcutAnchor else { return }
        presentDashboard(relativeTo: button)
    }

    /// Where the shortcut opens the dashboard: the middle metric item, so the
    /// panel centers under the group, or the icon-only fallback item.
    private var shortcutAnchor: NSStatusBarButton? {
        if !lastKindOrder.isEmpty,
           let button = statusItems[lastKindOrder[lastKindOrder.count / 2]]?.button {
            return button
        }
        return fallbackItem?.button
    }

    @objc public func closeDashboardIfShown() {
        guard isDashboardShown else { return }
        closeDashboard(nil)
    }

    private func closeDashboard(_ sender: Any?, restoringFocus: Bool = false) {
        if let panel {
            panel.dismiss(restoringFocus: restoringFocus)
        } else {
            popover?.performClose(sender)
        }
    }

    private func presentDashboard(relativeTo button: NSStatusBarButton) {
        MetricsCoordinator.shared.setDashboardVisible(true)
        if let panel {
            panel.show(below: button, content: DashboardView())
            return
        }
        guard let popover else { return }
        let host = NSHostingController(rootView: DashboardView())
        host.sizingOptions = [.intrinsicContentSize]
        popover.contentViewController = host
        let fitted = host.sizeThatFits(in: NSSize(width: DesignTokens.popoverWidth, height: .greatestFiniteMagnitude))
        popover.contentSize = NSSize(
            width: DesignTokens.popoverWidth,
            height: fitted.height > 0 ? fitted.height : DesignTokens.popoverHeight
        )
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    public func popoverDidClose(_ notification: Notification) {
        popover?.contentViewController = nil
        MetricsCoordinator.shared.setDashboardVisible(false)
    }
}

/// Compact status cell (value over TEM/MEM/CPU), drawn as a template image.
///
/// The menu bar tints template images for its own appearance, the same way it
/// does for system icons. Custom subviews (the earlier NSTextField approach)
/// get re-snapshotted by macOS 26+ every time their appearance flips, which
/// kept the main thread ~40% busy even with the dashboard closed.
@MainActor
private enum MetricStatusImage {
    /// Not the full 13pt `menuBarFont`: that is sized for one-line menu titles
    /// and looks huge in a two-line 29pt column.
    private static let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private static let labelFont = NSFont.systemFont(ofSize: 7.5, weight: .medium)

    static func make(value: String, label: String) -> NSImage {
        let size = NSSize(width: MenuBarRenderer.itemWidth, height: NSStatusBar.system.thickness)
        let image = NSImage(size: size, flipped: false) { rect in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byClipping
            func draw(_ text: String, font: NSFont, baselineY: CGFloat) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: paragraph
                ]
                let lineRect = NSRect(x: 0, y: baselineY + font.descender, width: rect.width, height: font.ascender - font.descender)
                (text as NSString).draw(with: lineRect, options: [.usesLineFragmentOrigin], attributes: attributes)
            }
            // Value flush to the top, TEM/MEM/CPU flush to the bottom.
            draw(value, font: valueFont, baselineY: rect.height - valueFont.ascender)
            draw(label, font: labelFont, baselineY: -labelFont.descender)
            return true
        }
        image.isTemplate = true
        return image
    }
}
