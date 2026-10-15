import SwiftUI

public struct UtilityGrid: View {
    @ObservedObject private var appearance = AppearanceController.shared
    @ObservedObject private var power = PowerController.shared
    @ObservedObject private var dock = DockController.shared
    @ObservedObject private var desktop = DesktopController.shared
    @ObservedObject private var cleaning = KeyboardCleaningController.shared
    @ObservedObject private var meeting = MeetingModeController.shared
    private let screen = ScreenController.shared
    private let trash = TrashController.shared

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.accent)

                Text("Utilities")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    UtilityButton(
                        title: "Meeting Mode",
                        icon: "person.2.wave.2",
                        isActive: meeting.isActive,
                        activeColor: DesignTokens.accent
                    ) {
                        meeting.toggle()
                    }

                    keepAwakeControl

                    UtilityButton(
                        title: "Dark Mode",
                        icon: appearance.isDarkMode ? "moon.fill" : "sun.max.fill",
                        isActive: appearance.isDarkMode,
                        activeColor: DesignTokens.accent
                    ) {
                        appearance.toggleDarkMode()
                    }

                    UtilityButton(
                        title: "Lock Screen",
                        icon: "lock.fill",
                        isActive: false,
                        activeColor: DesignTokens.accent
                    ) {
                        screen.lockScreen()
                    }

                    UtilityButton(
                        title: "Screen Saver",
                        icon: "sparkles.tv",
                        isActive: false,
                        activeColor: DesignTokens.accent
                    ) {
                        screen.startScreenSaver()
                    }

                    UtilityButton(
                        title: desktop.isDesktopIconsHidden ? "Show Desktop" : "Hide Desktop",
                        icon: "menubar.rectangle",
                        isActive: desktop.isDesktopIconsHidden,
                        activeColor: DesignTokens.accent
                    ) {
                        desktop.toggleDesktopIcons()
                    }

                    UtilityButton(
                        title: dock.isDockHidden ? "Show Dock" : "Hide Dock",
                        icon: "dock.rectangle",
                        isActive: dock.isDockHidden,
                        activeColor: DesignTokens.accent
                    ) {
                        dock.toggleDockAutoHide()
                    }

                    UtilityButton(
                        title: "Clean Keyboard",
                        icon: "keyboard",
                        isActive: cleaning.isActive && cleaning.activeMode == .keyboard,
                        activeColor: DesignTokens.accent
                    ) {
                        cleaning.startCleanKeyboard()
                    }

                    UtilityButton(
                        title: "Clean Screen",
                        icon: "display",
                        isActive: cleaning.isActive && cleaning.activeMode == .screen,
                        activeColor: DesignTokens.accent
                    ) {
                        cleaning.startCleanScreen()
                    }

                    UtilityButton(
                        title: "Copy Local IP",
                        icon: "network",
                        isActive: false,
                        activeColor: DesignTokens.accent
                    ) {
                        SystemUtilitiesController.copyLocalIPToClipboard()
                    }

                    UtilityButton(
                        title: "Clear Clipboard",
                        icon: "clipboard",
                        isActive: false,
                        activeColor: DesignTokens.accent
                    ) {
                        SystemUtilitiesController.clearClipboard()
                    }

                    UtilityButton(
                        title: "Screenshots",
                        icon: "photo.on.rectangle",
                        isActive: false,
                        activeColor: DesignTokens.accent
                    ) {
                        SystemUtilitiesController.openScreenshotsFolder()
                    }

                    UtilityButton(
                        title: "Eject Volumes",
                        icon: "eject.fill",
                        isActive: false,
                        activeColor: .red.opacity(0.9)
                    ) {
                        SystemUtilitiesController.ejectExternalVolumesWithConfirmation()
                    }

                    UtilityButton(
                        title: "Empty Trash",
                        icon: "trash",
                        isActive: false,
                        activeColor: .red.opacity(0.9)
                    ) {
                        trash.emptyTrashWithConfirmation()
                    }
                }
        }
        .padding(DesignTokens.cardPadding)
        .background(DesignTokens.cardBackground(reduceTransparency: reduceTransparency))
    }

    @ViewBuilder
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
                title: power.isKeepAwakeActive ? "Awake On" : "Keep Awake",
                icon: "cup.and.saucer.fill",
                isActive: power.isKeepAwakeActive,
                activeColor: DesignTokens.accent,
                subtitle: keepAwakeSubtitle
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var keepAwakeSubtitle: String? {
        guard power.isKeepAwakeActive, let end = power.keepAwakeEndsAt else {
            return power.isKeepAwakeActive ? "Until quit" : nil
        }
        let remaining = max(0, Int(end.timeIntervalSinceNow / 60))
        return "\(remaining)m left"
    }
}

private struct UtilityButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            UtilityButtonLabel(title: title, icon: icon, isActive: isActive, activeColor: activeColor)
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

private struct UtilityButtonLabel: View {
    let title: String
    let icon: String
    let isActive: Bool
    let activeColor: Color
    var subtitle: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isActive ? activeColor : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isActive {
                Circle()
                    .fill(activeColor)
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? activeColor.opacity(0.12) : Color.primary.opacity(0.04))
        )
        .contentShape(Rectangle())
    }
}
