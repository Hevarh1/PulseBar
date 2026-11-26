import AppKit
import ApplicationServices
import CoreGraphics

public enum CleanOverlayMode {
    case keyboard
    case screen
}

/// Lives off the main actor so the CGEvent tap C callback can touch it safely.
private final class CleanKeyTapBox: NSObject {
    var machPort: CFMachPort?
    var onEsc: ((Bool) -> Void)?
}

private func cleanKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let box = Unmanaged<CleanKeyTapBox>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let port = box.machPort {
            CGEvent.tapEnable(tap: port, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    switch type {
    case .keyDown, .keyUp, .flagsChanged:
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == 53 {
            box.onEsc?(type == .keyDown)
        }
        return nil
    default:
        return Unmanaged.passRetained(event)
    }
}

@MainActor
public final class KeyboardCleaningController: ObservableObject {
    public static let shared = KeyboardCleaningController()

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var activeMode: CleanOverlayMode?

    private var cleanWindows: [CleanOverlayWindow] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapBox: CleanKeyTapBox?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var activityMonitor: Any?

    private var holdTimer: Timer?
    private var failsafeTimer: Timer?
    private var hintHideTimer: Timer?
    private var escDown = false
    private var exitButtonDown = false
    private var previousActivationPolicy: NSApplication.ActivationPolicy?

    private let holdDuration: TimeInterval = 2.0
    /// Keys are blocked in keyboard mode, so it ends on its own sooner.
    private let keyboardFailsafe: TimeInterval = 90
    private let screenFailsafe: TimeInterval = 180
    /// Clean Screen shows its instructions this long, then goes fully black.
    private let hintVisibleDuration: TimeInterval = 3.0

    private init() {}

    public func startCleanKeyboard() {
        NotificationCenter.default.post(name: .pulseBarCloseDashboard, object: nil)
        // Defer so the popover can finish closing before we take over the screen.
        DispatchQueue.main.async { [weak self] in
            self?.present(mode: .keyboard)
        }
    }

    public func startCleanScreen() {
        NotificationCenter.default.post(name: .pulseBarCloseDashboard, object: nil)
        DispatchQueue.main.async { [weak self] in
            self?.present(mode: .screen)
        }
    }

    public func exitCleanMode() {
        holdTimer?.invalidate()
        holdTimer = nil
        failsafeTimer?.invalidate()
        failsafeTimer = nil
        hintHideTimer?.invalidate()
        hintHideTimer = nil
        escDown = false
        exitButtonDown = false

        tearDownEventTap()
        for monitor in [localMonitor, globalMonitor, activityMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        localMonitor = nil
        globalMonitor = nil
        activityMonitor = nil

        // Fade out; the windows stop taking clicks right away.
        let closing = cleanWindows
        cleanWindows = []
        for window in closing {
            window.ignoresMouseEvents = true
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            for window in closing {
                window.animator().alphaValue = 0
            }
        }, completionHandler: {
            for window in closing {
                window.orderOut(nil)
                window.close()
            }
        })

        if let previousActivationPolicy {
            NSApp.setActivationPolicy(previousActivationPolicy)
            self.previousActivationPolicy = nil
        }

        isActive = false
        activeMode = nil
    }

    // MARK: - Present

    private func present(mode: CleanOverlayMode) {
        guard !isActive, cleanWindows.isEmpty else { return }

        if mode == .keyboard && !ensureAccessibility() {
            return
        }

        previousActivationPolicy = NSApp.activationPolicy()
        // Accessory (LSUIElement) apps often cannot keep key windows / receive clicks reliably.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let screens = NSScreen.screens.isEmpty
            ? [NSScreen.main].compactMap { $0 }
            : NSScreen.screens

        for screen in screens {
            let window = CleanOverlayWindow(
                mode: mode,
                screen: screen,
                holdDuration: holdDuration
            ) { [weak self] pressed in
                self?.handleExitButton(pressed: pressed)
            }
            window.alphaValue = 0
            window.orderFrontRegardless()
            cleanWindows.append(window)
        }
        cleanWindows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            for window in cleanWindows {
                window.animator().alphaValue = 1
            }
        }

        isActive = true
        activeMode = mode

        if mode == .keyboard {
            installKeyBlocking()
        } else {
            // Screen mode doesn't block keys, but holding Esc still exits.
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                self?.noteEsc(down: event.type == .keyDown)
                return nil
            }
            // Any pointer activity brings the instructions back.
            activityMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
            ) { [weak self] event in
                self?.revealHint()
                return event
            }
            scheduleHintHide()
        }

        failsafeTimer?.invalidate()
        let failsafe = Timer(
            timeInterval: mode == .screen ? screenFailsafe : keyboardFailsafe,
            repeats: false
        ) { _ in
            Task { @MainActor in
                KeyboardCleaningController.shared.exitCleanMode()
            }
        }
        RunLoop.main.add(failsafe, forMode: .common)
        failsafeTimer = failsafe
    }

    private func ensureAccessibility() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) {
            return true
        }
        UtilityFeedback.showInfo(
            title: "Accessibility Required",
            message: "Enable PulseBar in System Settings → Privacy & Security → Accessibility, then try Clean Keyboard again. (The binary from `swift run` appears as “PulseBar”.)"
        )
        return false
    }

    // MARK: - Instructions (Clean Screen goes fully black)

    private func revealHint() {
        guard activeMode == .screen else { return }
        for window in cleanWindows {
            window.setHintVisible(true)
        }
        scheduleHintHide()
    }

    private func scheduleHintHide() {
        hintHideTimer?.invalidate()
        hintHideTimer = nil
        guard activeMode == .screen, !(exitButtonDown || escDown) else { return }
        let timer = Timer(timeInterval: hintVisibleDuration, repeats: false) { _ in
            Task { @MainActor in
                KeyboardCleaningController.shared.hideHint()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hintHideTimer = timer
    }

    private func hideHint() {
        guard activeMode == .screen, !(exitButtonDown || escDown) else { return }
        for window in cleanWindows {
            window.setHintVisible(false)
        }
        // Self-balancing: the cursor comes back on its own when the mouse moves.
        NSCursor.setHiddenUntilMouseMoves(true)
    }

    // MARK: - Exit hold

    private func handleExitButton(pressed: Bool) {
        exitButtonDown = pressed
        updateHoldState()
    }

    fileprivate func noteEsc(down: Bool) {
        // Key repeat sends more key-downs; only the first one starts a hold.
        guard escDown != down else { return }
        escDown = down
        updateHoldState()
    }

    private func updateHoldState() {
        if exitButtonDown || escDown {
            revealHint()
            hintHideTimer?.invalidate()
            hintHideTimer = nil
            startHoldIfNeeded()
        } else {
            cancelHold()
            scheduleHintHide()
        }
    }

    private func startHoldIfNeeded() {
        guard holdTimer == nil else { return }
        for window in cleanWindows {
            window.setHolding(true)
        }
        // The fill animates in Core Animation; this only ends the session.
        let timer = Timer(timeInterval: holdDuration, repeats: false) { _ in
            Task { @MainActor in
                KeyboardCleaningController.shared.exitCleanMode()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        for window in cleanWindows {
            window.setHolding(false)
        }
    }

    // MARK: - Key blocking

    private func installKeyBlocking() {
        // Local: when our overlay is key, swallow keys and track Esc.
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            if event.keyCode == 53 {
                self?.noteEsc(down: event.type == .keyDown)
            }
            return nil
        }

        // Global: observe Esc even if focus is stolen (cannot swallow here).
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp]
        ) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in
                    self?.noteEsc(down: event.type == .keyDown)
                }
            }
        }

        installEventTap()
    }

    private func installEventTap() {
        tearDownEventTap()

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let box = CleanKeyTapBox()
        box.onEsc = { down in
            DispatchQueue.main.async {
                KeyboardCleaningController.shared.noteEsc(down: down)
            }
        }

        let refcon = Unmanaged.passUnretained(box).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: cleanKeyTapCallback,
            userInfo: refcon
        ) else {
            UtilityFeedback.showInfo(
                title: "Could Not Block Keys",
                message: "macOS refused the event tap. Confirm Accessibility is enabled for PulseBar, then try again. Exit still works via the Exit button."
            )
            return
        }

        box.machPort = tap
        tapBox = box
        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func tearDownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        tapBox = nil
    }
}

// MARK: - Pure AppKit overlay (SwiftUI hit-testing is unreliable for hold-to-exit)

private final class CleanOverlayWindow: NSWindow {
    private let hintView = NSView()
    private let exitButton: HoldExitButton

    init(
        mode: CleanOverlayMode,
        screen: NSScreen,
        holdDuration: TimeInterval,
        onExitPress: @escaping (Bool) -> Void
    ) {
        exitButton = HoldExitButton(holdDuration: holdDuration)

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: true)
        // Clean Screen is solid black edge to edge so dust and smudges show;
        // Clean Keyboard only needs a dim.
        isOpaque = mode == .screen
        backgroundColor = mode == .screen ? .black : .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)

        let root = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        root.wantsLayer = true
        root.layer?.backgroundColor = mode == .screen
            ? NSColor.black.cgColor
            : NSColor.black.withAlphaComponent(0.94).cgColor
        contentView = root

        hintView.wantsLayer = true
        hintView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(hintView)

        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: mode == .keyboard ? "keyboard" : "sparkles",
            accessibilityDescription: nil
        )
        icon.contentTintColor = NSColor.white.withAlphaComponent(0.85)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 40, weight: .light)

        let title = Self.makeLabel(
            mode == .keyboard ? "Clean Keyboard" : "Clean Screen",
            size: 26,
            weight: .semibold,
            color: .white
        )
        let subtitle = Self.makeLabel(
            mode == .keyboard
                ? "All keys are blocked while you wipe."
                : "Wipe away. Move the mouse to see this again.",
            size: 14,
            weight: .regular,
            color: NSColor.white.withAlphaComponent(0.6)
        )
        subtitle.maximumNumberOfLines = 2
        subtitle.preferredMaxLayoutWidth = 420

        let exitHint = Self.makeLabel(
            "Hold Esc or the button for \(Int(holdDuration)) seconds to exit",
            size: 12,
            weight: .medium,
            color: NSColor.white.withAlphaComponent(0.4)
        )

        exitButton.onPressedChanged = onExitPress
        // VoiceOver can't hold a button down; its press exits directly.
        exitButton.onAccessibilityPress = {
            DispatchQueue.main.async { KeyboardCleaningController.shared.exitCleanMode() }
        }
        exitButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [icon, title, subtitle, exitButton, exitHint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(18, after: icon)
        stack.setCustomSpacing(32, after: subtitle)
        stack.setCustomSpacing(14, after: exitButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        hintView.addSubview(stack)

        NSLayoutConstraint.activate([
            hintView.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            hintView.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            hintView.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 40),
            hintView.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -40),

            stack.leadingAnchor.constraint(equalTo: hintView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: hintView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: hintView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: hintView.bottomAnchor),

            exitButton.widthAnchor.constraint(equalToConstant: 220),
            exitButton.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    func setHintVisible(_ visible: Bool) {
        let target: CGFloat = visible ? 1 : 0
        guard hintView.alphaValue != target else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = visible ? 0.2 : 0.8
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            hintView.animator().alphaValue = target
        }
    }

    func setHolding(_ holding: Bool) {
        exitButton.setHolding(holding)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private static func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = .center
        return field
    }
}

/// Capsule that fills left to right while held; the fill is a Core Animation
/// layer so it moves at display refresh rate.
private final class HoldExitButton: NSButton {
    var onPressedChanged: ((Bool) -> Void)?
    var onAccessibilityPress: (() -> Void)?

    private let holdDuration: TimeInterval
    private let fillLayer = CALayer()
    private let labelLayer = CATextLayer()
    private var isPressed = false
    private var isHolding = false

    init(holdDuration: TimeInterval) {
        self.holdDuration = holdDuration
        super.init(frame: .zero)
        // The label is a layer (drawn over the fill); the cell draws no title.
        title = ""
        setAccessibilityLabel("Exit")
        isBordered = false
        wantsLayer = true
        setButtonType(.momentaryChange)
        // VoiceOver presses the button's cell, which sends this action;
        // mouseDown is overridden, so a mouse click never does.
        target = self
        action = #selector(accessibilityPressed(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer else { return }
        layer.backgroundColor = NSColor.white.withAlphaComponent(isPressed ? 0.18 : 0.12).cgColor
        layer.cornerRadius = bounds.height / 2
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor

        if fillLayer.superlayer == nil {
            fillLayer.backgroundColor = NSColor.white.withAlphaComponent(0.32).cgColor
            fillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
            layer.addSublayer(fillLayer)

            labelLayer.string = "Hold to Exit"
            labelLayer.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
            labelLayer.fontSize = 15
            labelLayer.alignmentMode = .center
            labelLayer.foregroundColor = NSColor.white.cgColor
            layer.addSublayer(labelLayer)
        }
    }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.bounds = CGRect(x: 0, y: 0, width: isHolding ? bounds.width : 0, height: bounds.height)
        fillLayer.position = CGPoint(x: 0, y: bounds.midY)
        labelLayer.contentsScale = scale
        labelLayer.frame = CGRect(x: 0, y: (bounds.height - 19) / 2, width: bounds.width, height: 19)
        CATransaction.commit()
    }

    func setHolding(_ holding: Bool) {
        guard holding != isHolding else { return }
        isHolding = holding
        let current = fillLayer.presentation()?.bounds.width ?? fillLayer.bounds.width
        let target = holding ? bounds.width : 0
        let remaining = holding && bounds.width > 0
            ? holdDuration * Double(1 - current / bounds.width)
            : 0.25

        let animation = CABasicAnimation(keyPath: "bounds.size.width")
        animation.fromValue = current
        animation.toValue = target
        animation.duration = max(0.01, remaining)
        animation.timingFunction = CAMediaTimingFunction(name: holding ? .linear : .easeOut)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.bounds.size.width = target
        fillLayer.add(animation, forKey: "fill")
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        onPressedChanged?(true)
    }

    override func mouseUp(with event: NSEvent) {
        guard isPressed else { return }
        isPressed = false
        needsDisplay = true
        onPressedChanged?(false)
    }

    @objc private func accessibilityPressed(_ sender: Any?) {
        onAccessibilityPress?()
    }
}
