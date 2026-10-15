import SwiftUI

/// A keyboard shortcut drawn as a small keycap, e.g. ⌃⌘P.
struct ShortcutKeycap: View {
    let shortcut: GlobalHotKey.Shortcut

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        Text(shortcut.displayString)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(DesignTokens.secondaryText)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.primary.opacity(0.08), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Keyboard shortcut \(shortcut.spokenString)")
    }
}
