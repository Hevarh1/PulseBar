import AppKit
import Carbon.HIToolbox

/// "PBAR": tags this app's hot keys so the handler ignores anyone else's.
private let hotKeySignature: OSType = 0x5042_4152

/// Carbon hands every hot key event for this app to each installed handler;
/// each instance checks the ID and fires only for its own registration.
private let hotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == hotKeySignature else {
        return OSStatus(eventNotHandledErr)
    }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    // Carbon delivers hot key events on the main thread.
    return MainActor.assumeIsolated { hotKey.handlePress(id: hotKeyID.id) }
}

/// A system-wide keyboard shortcut. Uses Carbon's `RegisterEventHotKey`,
/// which needs no Accessibility or Input Monitoring permission.
@MainActor
final class GlobalHotKey {
    struct Shortcut: Equatable {
        let keyCode: UInt32
        let modifiers: NSEvent.ModifierFlags
        /// The key as printed on the keycap, e.g. "P".
        let key: String

        /// Menu-style text in Apple's modifier order, e.g. "⌃⌘P".
        var displayString: String {
            var text = ""
            if modifiers.contains(.control) { text += "⌃" }
            if modifiers.contains(.option) { text += "⌥" }
            if modifiers.contains(.shift) { text += "⇧" }
            if modifiers.contains(.command) { text += "⌘" }
            return text + key
        }

        /// VoiceOver wording, e.g. "Control Command P".
        var spokenString: String {
            var words: [String] = []
            if modifiers.contains(.control) { words.append("Control") }
            if modifiers.contains(.option) { words.append("Option") }
            if modifiers.contains(.shift) { words.append("Shift") }
            if modifiers.contains(.command) { words.append("Command") }
            return (words + [key]).joined(separator: " ")
        }

        var carbonModifiers: UInt32 {
            var flags = 0
            if modifiers.contains(.control) { flags |= controlKey }
            if modifiers.contains(.option) { flags |= optionKey }
            if modifiers.contains(.shift) { flags |= shiftKey }
            if modifiers.contains(.command) { flags |= cmdKey }
            return UInt32(flags)
        }
    }

    private static var nextID: UInt32 = 1

    private let id: UInt32
    private let onPress: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Returns nil when Carbon refuses the registration (for example, this app
    /// already registered the same keys). Carbon does not stop two different
    /// apps from registering the same combination.
    init?(_ shortcut: Shortcut, onPress: @escaping () -> Void) {
        self.id = Self.nextID
        Self.nextID += 1
        self.onPress = onPress

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            EventHotKeyID(signature: hotKeySignature, id: id),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            invalidate()
            return nil
        }
    }

    deinit {
        // The handler holds an unretained pointer to self.
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    func invalidate() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }

    fileprivate func handlePress(id: UInt32) -> OSStatus {
        guard id == self.id else { return OSStatus(eventNotHandledErr) }
        onPress()
        return noErr
    }
}

/// The global shortcut that shows or hides the dashboard, and whether it is
/// registered right now (the header and Settings only show it then).
@MainActor
final class DashboardShortcut: ObservableObject {
    static let shared = DashboardShortcut()

    /// ⌃⌘P: two modifiers, "P" for PulseBar, and unlike ⌥⌘P it doesn't take
    /// over Finder's Show Path Bar or Xcode's Resume Preview.
    static let shortcut = GlobalHotKey.Shortcut(
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: [.control, .command],
        key: "P"
    )

    /// False when turned off in Settings or when registration failed.
    @Published private(set) var isRegistered = false
    var onPress: (() -> Void)?

    private var hotKey: GlobalHotKey?

    private init() {}

    func setEnabled(_ enabled: Bool) {
        if enabled {
            if hotKey == nil {
                hotKey = GlobalHotKey(Self.shortcut) { [weak self] in
                    self?.onPress?()
                }
            }
        } else {
            hotKey?.invalidate()
            hotKey = nil
        }
        isRegistered = hotKey != nil
    }
}
