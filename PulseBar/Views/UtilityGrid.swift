import SwiftUI

/// Control Center–style utilities: a four-column grid of icon tiles, with the
/// two confirm-first actions as wide tiles on the last row.
public struct UtilityGrid: View {
    @ObservedObject private var appearance = AppearanceController.shared
    @ObservedObject private var power = PowerController.shared
    @ObservedObject private var dock = DockController.shared
    @ObservedObject private var desktop = DesktopController.shared
    @ObservedObject private var meeting = MeetingModeController.shared
    private let cleaning = KeyboardCleaningController.shared
    private let screen = ScreenController.shared
    private let trash = TrashController.shared

    /// Title of the action that just ran, shown with a checkmark for a moment.
    @State private var confirmed: String?
    @State private var confirmTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        Grid(horizontalSpacing: DesignTokens.gridSpacing, verticalSpacing: DesignTokens.gridSpacing) {
            GridRow {
                UtilityTile(title: "Meeting Mode", icon: "person.2.wave.2", isActive: meeting.isActive) {
                    meeting.toggle()
                }
                keepAwakeControl
                UtilityTile(
                    title: "Dark Mode",
                    icon: appearance.isDarkMode ? "moon.fill" : "sun.max.fill",
                    isActive: appearance.isDarkMode
                ) {
                    appearance.toggleDarkMode()
                }
                UtilityTile(title: "Lock Screen", icon: "lock.fill") {
                    screen.lockScreen()
                }
            }

            GridRow {
                // Stable titles: the toggle's on state means "hidden", as in Control Center.
                UtilityTile(title: "Hide Dock", icon: "dock.rectangle", isActive: dock.isDockHidden) {
                    dock.toggleDockAutoHide()
                }
                UtilityTile(title: "Hide Desktop", icon: "menubar.rectangle", isActive: desktop.isDesktopIconsHidden) {
                    desktop.toggleDesktopIcons()
                }
                UtilityTile(title: "Screen Saver", icon: "sparkles.tv") {
                    screen.startScreenSaver()
                }
                UtilityTile(title: "Screenshots", icon: "photo.on.rectangle") {
                    SystemUtilitiesController.openScreenshotsFolder()
                }
            }

            GridRow {
                // Actions, not toggles: the overlay covers the panel while active.
                UtilityTile(title: "Clean Screen", icon: "display") {
                    cleaning.startCleanScreen()
                }
                UtilityTile(title: "Clean Keyboard", icon: "keyboard") {
                    cleaning.startCleanKeyboard()
                }
                confirmingTile(title: "Copy IP", icon: "network", done: "Copied") {
                    SystemUtilitiesController.copyLocalIPToClipboard()
                }
                confirmingTile(title: "Clear Clipboard", icon: "clipboard", done: "Cleared") {
                    SystemUtilitiesController.clearClipboard()
                }
            }

            GridRow {
                WideUtilityTile(title: "Eject Volumes", icon: "eject.fill") {
                    SystemUtilitiesController.ejectExternalVolumesWithConfirmation()
                }
                .gridCellColumns(2)
                WideUtilityTile(title: "Empty Trash", icon: "trash") {
                    trash.emptyTrashWithConfirmation()
                }
                .gridCellColumns(2)
            }
        }
        .onAppear {
            // These can change outside PulseBar (System Settings, Terminal).
            dock.checkDockState()
            desktop.checkDesktopState()
            appearance.checkCurrentAppearance()
        }
        .onDisappear {
            confirmTask?.cancel()
        }
    }

    /// An action tile that briefly swaps to a checkmark after it runs, so a
    /// silent action (clipboard) visibly did something.
    private func confirmingTile(title: String, icon: String, done: String, action: @escaping () -> Void) -> some View {
        let isConfirmed = confirmed == title
        return UtilityTile(
            title: isConfirmed ? done : title,
            icon: isConfirmed ? "checkmark" : icon,
            isActive: isConfirmed
        ) {
            action()
            confirmTask?.cancel()
            confirmed = title
            confirmTask = Task {
                try? await Task.sleep(for: .seconds(1.4))
                guard !Task.isCancelled else { return }
                confirmed = nil
            }
        }
    }

    private var keepAwakeControl: some View {
        Menu {
            Button("30 minutes") { power.enableKeepAwakeFor(minutes: 30) }
            Button("1 hour") { power.enableKeepAwakeFor(minutes: 60) }
            Button("Until quit") { power.enableKeepAwake(until: nil) }
            if power.isKeepAwakeActive {
                Divider()
                Button("Turn Off") { power.disableKeepAwake() }
            }
        } label: {
            UtilityTileLabel(
                title: power.isKeepAwakeActive ? (keepAwakeSubtitle ?? "Keep Awake") : "Keep Awake",
                icon: "cup.and.saucer.fill",
                isActive: power.isKeepAwakeActive
            )
        }
        // `.button` keeps the custom label; `.borderlessButton` flattens it
        // to a plain title and image.
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(GlassTileButtonStyle())
        .accessibilityLabel("Keep Awake")
        .accessibilityValue(power.isKeepAwakeActive ? "On, \(keepAwakeSubtitle ?? "")" : "Off")
    }

    private var keepAwakeSubtitle: String? {
        guard power.isKeepAwakeActive, let end = power.keepAwakeEndsAt else {
            return power.isKeepAwakeActive ? "Until quit" : nil
        }
        let remaining = max(0, Int(end.timeIntervalSinceNow / 60))
        return remaining >= 60 ? "\(remaining / 60)h \(remaining % 60)m left" : "\(remaining)m left"
    }
}

/// Glass icon tile. `isActive` (when non-nil) marks it as a toggle.
private struct UtilityTile: View {
    let title: String
    let icon: String
    var isActive: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            UtilityTileLabel(title: title, icon: icon, isActive: isActive ?? false)
        }
        .buttonStyle(GlassTileButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive == nil ? [] : .isToggle)
        .accessibilityValue(isActive.map { $0 ? "On" : "Off" } ?? "")
    }
}

private struct UtilityTileLabel: View {
    let title: String
    let icon: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 6) {
            IconWell(systemName: icon, style: .toggle(isOn: isActive), size: 28)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.utilityTileHeight)
        .animation(.smooth(duration: 0.2), value: title)
    }
}

/// Wide action tile (icon beside label) for the last row.
private struct WideUtilityTile: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                IconWell(systemName: icon, style: .toggle(isOn: false), size: 26)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.controlHeight + 4, alignment: .leading)
        }
        .buttonStyle(GlassTileButtonStyle())
        .accessibilityLabel(title)
    }
}
