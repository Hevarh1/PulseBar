import SwiftUI

public struct UtilityGrid: View {
    @ObservedObject private var appearance = AppearanceController.shared
    @ObservedObject private var power = PowerController.shared
    @ObservedObject private var dock = DockController.shared
    @ObservedObject private var desktop = DesktopController.shared
    @ObservedObject private var meeting = MeetingModeController.shared
    private let cleaning = KeyboardCleaningController.shared
    private let screen = ScreenController.shared
    private let trash = TrashController.shared

    public init() {}

    public var body: some View {
        Grid(horizontalSpacing: DesignTokens.gridSpacing, verticalSpacing: DesignTokens.gridSpacing) {
            GridRow {
                UtilityButton(title: "Meeting Mode", icon: "person.2.wave.2", isActive: meeting.isActive) {
                    meeting.toggle()
                }
                keepAwakeControl
            }

            GridRow {
                UtilityButton(
                    title: "Dark Mode",
                    icon: appearance.isDarkMode ? "moon.fill" : "sun.max.fill",
                    isActive: appearance.isDarkMode
                ) {
                    appearance.toggleDarkMode()
                }
                UtilityButton(title: "Lock Screen", icon: "lock.fill") {
                    screen.lockScreen()
                }
            }

            GridRow {
                UtilityButton(title: "Screen Saver", icon: "sparkles.tv") {
                    screen.startScreenSaver()
                }
                // Stable titles: the toggle's on state means "hidden", as in Control Center.
                UtilityButton(title: "Hide Desktop", icon: "menubar.rectangle", isActive: desktop.isDesktopIconsHidden) {
                    desktop.toggleDesktopIcons()
                }
            }

            GridRow {
                UtilityButton(title: "Hide Dock", icon: "dock.rectangle", isActive: dock.isDockHidden) {
                    dock.toggleDockAutoHide()
                }
                // Actions, not toggles: the overlay covers the panel while active.
                UtilityButton(title: "Clean Keyboard", icon: "keyboard") {
                    cleaning.startCleanKeyboard()
                }
            }

            GridRow {
                UtilityButton(title: "Clean Screen", icon: "display") {
                    cleaning.startCleanScreen()
                }
                UtilityButton(title: "Copy Local IP", icon: "network") {
                    SystemUtilitiesController.copyLocalIPToClipboard()
                }
            }

            GridRow {
                UtilityButton(title: "Clear Clipboard", icon: "clipboard") {
                    SystemUtilitiesController.clearClipboard()
                }
                UtilityButton(title: "Screenshots", icon: "photo.on.rectangle") {
                    SystemUtilitiesController.openScreenshotsFolder()
                }
            }

            GridRow {
                UtilityButton(title: "Eject Volumes", icon: "eject.fill") {
                    SystemUtilitiesController.ejectExternalVolumesWithConfirmation()
                }
                UtilityButton(title: "Empty Trash", icon: "trash") {
                    trash.emptyTrashWithConfirmation()
                }
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
            UtilityButtonLabel(
                title: "Keep Awake",
                icon: "cup.and.saucer.fill",
                isActive: power.isKeepAwakeActive,
                subtitle: keepAwakeSubtitle
            )
        }
        // `.button` keeps the custom label; `.borderlessButton` flattens it
        // to a plain title and image.
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(GlassCapsuleButtonStyle())
        .accessibilityValue(power.isKeepAwakeActive ? "On, \(keepAwakeSubtitle ?? "")" : "Off")
    }

    private var keepAwakeSubtitle: String? {
        guard power.isKeepAwakeActive, let end = power.keepAwakeEndsAt else {
            return power.isKeepAwakeActive ? "Until quit" : nil
        }
        let remaining = max(0, Int(end.timeIntervalSinceNow / 60))
        return "\(remaining)m left"
    }
}

/// Glass capsule control. `isActive` (when non-nil) marks it as a toggle.
private struct UtilityButton: View {
    let title: String
    let icon: String
    var isActive: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            UtilityButtonLabel(title: title, icon: icon, isActive: isActive ?? false)
        }
        .buttonStyle(GlassCapsuleButtonStyle())
        .accessibilityAddTraits(isActive == nil ? [] : .isToggle)
        .accessibilityValue(isActive.map { $0 ? "On" : "Off" } ?? "")
    }
}

private struct UtilityButtonLabel: View {
    let title: String
    let icon: String
    let isActive: Bool
    var subtitle: String?

    var body: some View {
        HStack(spacing: 8) {
            IconWell(systemName: icon, style: .toggle(isOn: isActive))

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        // Inset matches the well's radius so the capsule stays concentric.
        .padding(.leading, (DesignTokens.controlHeight - DesignTokens.iconWellSize) / 2)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.controlHeight, alignment: .leading)
        .contentShape(Capsule())
    }
}
