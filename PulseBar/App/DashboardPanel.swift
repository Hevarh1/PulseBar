import AppKit
import SwiftUI

/// Transparent, borderless panel that floats the dashboard's glass tiles
/// directly over the desktop, the way Control Center presents its modules.
/// An NSPopover always draws its own glass pane, which would turn every tile
/// into glass-on-glass, so this is used whenever Liquid Glass is available.
@MainActor
final class DashboardPanel: NSPanel {
    private(set) var isShown = false
    /// Called once each time the panel goes away (Esc, focus loss, outside click).
    var onClose: (() -> Void)?

    private var eventMonitors: [Any] = []
    private var windowObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var presentationID = 0
    private var presentation: PanelPresentation?
    /// Frontmost app before the panel opened, so an explicit close (Esc, the
    /// shortcut, the status item) can hand keyboard focus back to it.
    private var previousApp: NSRunningApplication?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        // Must be set explicitly: by default AppKit lets clicks on transparent
        // pixels (the gaps between tiles) fall through to the app underneath.
        ignoresMouseEvents = false
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        // Never drawn (borderless); gives VoiceOver a name for the window.
        title = "PulseBar"
    }

    private static let closeDuration: TimeInterval = 0.16

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc closes the panel, like a popover.
    override func cancelOperation(_ sender: Any?) {
        dismiss(restoringFocus: true)
    }

    /// Shows `content` centered under `anchor`, kept inside the anchor's screen.
    func show(below anchor: NSView, content: some View) {
        guard let anchorWindow = anchor.window else { return }
        presentationID += 1

        let anchorRect = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let visible = (anchorWindow.screen ?? NSScreen.main)?.visibleFrame ?? anchorRect
        // Hang from the menu bar's bottom edge (the status button is shorter
        // than a notched menu bar); falls back to the button when it auto-hides.
        let top = min(anchorRect.minY, visible.maxY)
        let available = top - visible.minY

        // Fresh view per presentation; the previous one is released here,
        // never while one of its button actions might still be running.
        let presentation = PanelPresentation()
        self.presentation = presentation
        let host = NSHostingView(rootView: PresentedDashboard(presentation: presentation, content: content))
        var size = host.fittingSize
        if size.height > available {
            // Display shorter than the dashboard: scroll so the footer stays reachable.
            let scrollHost = NSHostingView(rootView: PresentedDashboard(
                presentation: presentation,
                content: ScrollView(.vertical) { content }
            ))
            contentView = scrollHost
            // Width from the scroll host: a legacy (always-visible) scroller adds to it.
            size = NSSize(width: scrollHost.fittingSize.width, height: available)
        } else {
            contentView = host
        }

        var origin = NSPoint(x: anchorRect.midX - size.width / 2, y: top - size.height)
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        setFrame(NSRect(origin: origin, size: size), display: false)

        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost == NSRunningApplication.current ? nil : frontmost
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        isShown = true
        installDismissTriggers()
        // Drop in from the menu bar once the hidden first frame is up.
        DispatchQueue.main.async { [weak presentation] in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                presentation?.isPresented = true
            }
        }
    }

    /// - Parameter restoringFocus: Reactivate the app that was frontmost
    ///   before the panel opened. Pass true for explicit closes; when the panel
    ///   closes because another app took focus, that app already has it.
    func dismiss(restoringFocus: Bool = false) {
        guard isShown else { return }
        isShown = false
        removeDismissTriggers()
        if restoringFocus, let previousApp, !previousApp.isTerminated {
            NSApp.yieldActivation(to: previousApp)
            previousApp.activate()
        }
        previousApp = nil

        let id = presentationID
        withAnimation(.easeIn(duration: Self.closeDuration)) {
            presentation?.isPresented = false
        }
        // A fixed delay rather than an animation completion, so an invisible
        // panel can never be left on screen catching clicks.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.closeDuration + 0.02) { [weak self] in
            // Skip if the panel was shown again while closing.
            guard let self, self.presentationID == id else { return }
            self.orderOut(nil)
            self.releaseContent(presentationID: id)
        }
        onClose?()
    }

    /// Drops the hidden dashboard so it stops re-rendering on every sample.
    /// Runs only in the default run-loop mode, so never while a button action
    /// is still inside a nested modal alert or menu-tracking loop.
    private func releaseContent(presentationID id: Int) {
        RunLoop.main.perform(inModes: [.default]) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.presentationID == id, !self.isShown else { return }
                self.contentView = nil
                self.presentation = nil
            }
        }
    }

    private func installDismissTriggers() {
        // Clicks in other apps, on the desktop, or on other menu bar items.
        if let monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.dismiss()
                }
            }
        ) {
            eventMonitors.append(monitor)
        }

        // Another window (Settings, an alert) took focus, or the app deactivated.
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismiss()
            }
        })

        workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismiss()
            }
        })
    }

    private func removeDismissTriggers() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
        windowObservers.forEach(NotificationCenter.default.removeObserver)
        windowObservers.removeAll()
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
    }
}

/// Drives the panel's open and close animation.
@MainActor
private final class PanelPresentation: ObservableObject {
    @Published var isPresented = false
}

/// Drops the dashboard from the menu bar with a spring on open and lifts it
/// away on close. Scale and offset are render-only, so the fitted size is
/// unaffected; sections cascade in through `dashboardRevealed`.
private struct PresentedDashboard<Content: View>: View {
    @ObservedObject var presentation: PanelPresentation
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = presentation.isPresented
        content
            .environment(\.dashboardRevealed, shown)
            .scaleEffect(shown || reduceMotion ? 1 : 0.94, anchor: .top)
            .offset(y: shown || reduceMotion ? 0 : -10)
            .opacity(shown ? 1 : 0)
    }
}
