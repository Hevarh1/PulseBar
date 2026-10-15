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
    @Published public private(set) var exitHoldProgress: Double = 0

    private var cleanWindows: [CleanOverlayWindow] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapBox: CleanKeyTapBox?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    private var holdTimer: Timer?
    private var failsafeTimer: Timer?
    private var holdStartedAt: Date?
    private var escDown = false
    private var exitButtonDown = false
    private var previousActivationPolicy: NSApplication.ActivationPolicy?

    private let holdDuration: TimeInterval = 2.0
    private let failsafeDuration: TimeInterval = 90

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
        stopHoldTimer()
        failsafeTimer?.invalidate()
        failsafeTimer = nil
        holdStartedAt = nil
        escDown = false
        exitButtonDown = false
        exitHoldProgress = 0

        tearDownEventTap()
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        for window in cleanWindows {
            window.orderOut(nil)
            window.close()
        }
        cleanWindows = []

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
            let window = CleanOverlayWindow(mode: mode, screen: screen) { [weak self] pressed in
                self?.handleExitButton(pressed: pressed)
            }
            window.orderFrontRegardless()
            cleanWindows.append(window)
        }
        cleanWindows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        isActive = true
        activeMode = mode
        exitHoldProgress = 0

        if mode == .keyboard {
            installKeyBlocking()
        }

        failsafeTimer?.invalidate()
        failsafeTimer = Timer.scheduledTimer(withTimeInterval: failsafeDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.exitCleanMode()
            }
        }
        if let failsafeTimer {
            RunLoop.main.add(failsafeTimer, forMode: .common)
        }
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

    // MARK: - Exit hold

    private func handleExitButton(pressed: Bool) {
        exitButtonDown = pressed
        updateHoldState()
    }

    fileprivate func noteEsc(down: Bool) {
        escDown = down
        updateHoldState()
    }

    private func updateHoldState() {
        let shouldHold = exitButtonDown || escDown
        if shouldHold {
            startHoldTimerIfNeeded()
        } else {
            stopHoldTimer()
        }
    }

    private func startHoldTimerIfNeeded() {
        guard holdTimer == nil else { return }
        holdStartedAt = Date()
        exitHoldProgress = 0
        // Refresh every window's progress bar.
        for window in cleanWindows {
            window.setHoldProgress(0)
        }

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickHold()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func tickHold() {
        guard let holdStartedAt, exitButtonDown || escDown else {
            stopHoldTimer()
            return
        }
        let elapsed = Date().timeIntervalSince(holdStartedAt)
        let progress = min(1, elapsed / holdDuration)
        exitHoldProgress = progress
        for window in cleanWindows {
            window.setHoldProgress(progress)
        }
        if progress >= 1 {
            exitCleanMode()
        }
    }

    private func stopHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdStartedAt = nil
        exitHoldProgress = 0
        for window in cleanWindows {
            window.setHoldProgress(0)
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
                Task { @MainActor in
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
    private let progressFillWidth: NSLayoutConstraint
    private let onExitPress: (Bool) -> Void

    init(mode: CleanOverlayMode, screen: NSScreen, onExitPress: @escaping (Bool) -> Void) {
        self.onExitPress = onExitPress

        let progressBar = NSView(frame: .zero)
        progressBar.wantsLayer = true
        progressBar.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        progressBar.layer?.cornerRadius = 4

        let progressFill = NSView(frame: .zero)
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = NSColor.systemBlue.cgColor
        progressFill.layer?.cornerRadius = 4

        let fillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        self.progressFillWidth = fillWidth

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false

        let root = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.withAlphaComponent(mode == .screen ? 0.88 : 0.94).cgColor
        contentView = root

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        let icon = NSImageView()
        let symbol = mode == .keyboard ? "keyboard" : "display"
        icon.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: nil
        )
        icon.contentTintColor = NSColor.systemBlue
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 52, weight: .light)

        let title = makeLabel(
            mode == .keyboard ? "Clean Keyboard" : "Clean Screen",
            size: 28,
            weight: .bold,
            color: .white
        )
        let subtitle = makeLabel(
            mode == .keyboard
                ? "Keys are blocked. Hold Esc or the Exit button for 2 seconds to finish."
                : "Screen dimmed for cleaning. Hold Exit for 2 seconds to finish.",
            size: 14,
            weight: .regular,
            color: .secondaryLabelColor
        )
        subtitle.maximumNumberOfLines = 3
        subtitle.preferredMaxLayoutWidth = 420
        subtitle.alignment = .center

        let holdHint = makeLabel("Hold Exit", size: 13, weight: .medium, color: .white.withAlphaComponent(0.75))

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBar.addSubview(progressFill)

        let exitButton = HoldExitButton()
        exitButton.title = "Exit"
        exitButton.onPressedChanged = onExitPress
        exitButton.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(holdHint)
        stack.addArrangedSubview(progressBar)
        stack.addArrangedSubview(exitButton)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -40),

            progressBar.widthAnchor.constraint(equalToConstant: 260),
            progressBar.heightAnchor.constraint(equalToConstant: 8),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBar.bottomAnchor),
            fillWidth,

            exitButton.widthAnchor.constraint(equalToConstant: 160),
            exitButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func setHoldProgress(_ progress: Double) {
        progressFillWidth.constant = 260 * max(0, min(1, progress))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = .center
        return field
    }
}

private final class HoldExitButton: NSButton {
    var onPressedChanged: ((Bool) -> Void)?
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        isBordered = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        layer?.cornerRadius = 10
        contentTintColor = .white
        font = .systemFont(ofSize: 15, weight: .semibold)
        focusRingType = .none
        setButtonType(.momentaryChange)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.28).cgColor
        onPressedChanged?(true)
    }

    override func mouseUp(with event: NSEvent) {
        if isPressed {
            isPressed = false
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
            onPressedChanged?(false)
        }
    }

    override func mouseExited(with event: NSEvent) {
        // Keep hold if they drift slightly; mouseUp still ends it.
    }
}
