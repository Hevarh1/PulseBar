import SwiftUI

// Liquid Glass on macOS 26+, a frosted fallback on macOS 14–15, and a solid
// fill when Reduce Transparency is on. Every glass availability check lives in
// this file so the views never branch on OS version.

enum LiquidGlass {
    /// True when the glass APIs are compiled in and available at runtime.
    static var isAvailable: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { return true }
        #endif
        return false
    }
}

extension View {
    /// Draws a glass surface behind the view in `shape`.
    /// - Parameters:
    ///   - interactive: Adds hover/press feedback (system glass response on
    ///     macOS 26+, a highlight on older systems).
    ///   - isPressed: Press state from a `ButtonStyle`, used by the fallback.
    func glassSurface<S: InsettableShape>(
        in shape: S,
        interactive: Bool = false,
        isPressed: Bool = false
    ) -> some View {
        modifier(GlassSurfaceModifier(shape: shape, interactive: interactive, isPressed: isPressed))
    }

    /// Rounded glass platter for content groups such as metric tiles.
    func glassPlatter(cornerRadius: CGFloat = DesignTokens.cardRadius) -> some View {
        glassSurface(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct GlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let isPressed: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            surface(
                content,
                fill: Color(nsColor: .controlBackgroundColor),
                rim: AnyShapeStyle(Color(nsColor: .separatorColor))
            )
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular.interactive(interactive), in: shape)
            } else {
                frosted(content)
            }
            #else
            frosted(content)
            #endif
        }
    }

    /// Pre-Tahoe Control Center look: translucent platter, bright top rim, soft shadow.
    private func frosted(_ content: Content) -> some View {
        let dark = colorScheme == .dark
        let rim = contrast == .increased
            ? AnyShapeStyle(Color.primary.opacity(0.35))
            : AnyShapeStyle(LinearGradient(
                colors: [.white.opacity(dark ? 0.24 : 0.9), .white.opacity(dark ? 0.05 : 0.35)],
                startPoint: .top,
                endPoint: .bottom
            ))
        return surface(
            content,
            fill: .white.opacity(dark ? 0.08 : 0.42),
            rim: rim,
            shadow: .black.opacity(dark ? 0.28 : 0.08)
        )
    }

    private func surface(_ content: Content, fill: Color, rim: AnyShapeStyle, shadow: Color = .clear) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(fill).shadow(color: shadow, radius: 5, y: 2)
                    if interactive {
                        shape.fill(Color.primary.opacity(isPressed ? 0.10 : (isHovered ? 0.05 : 0)))
                    }
                }
            }
            .overlay {
                shape
                    .strokeBorder(rim, lineWidth: contrast == .increased ? 1 : 0.75)
                    .allowsHitTesting(false)
            }
            .onHover { hovering in
                guard interactive else { return }
                withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
            }
    }
}

/// Lets sibling glass surfaces sample and render together (macOS 26+).
/// A plain passthrough on older systems.
struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer { content() }
        } else {
            content()
        }
        #else
        content()
        #endif
    }
}

/// Capsule glass button. The label supplies its own layout and padding.
struct GlassCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Capsule())
            .glassSurface(in: Capsule(), interactive: true, isPressed: configuration.isPressed)
    }
}

/// Control Center–style round glyph well.
struct IconWell: View {
    enum Style {
        /// Metric identity: tinted disc with a white glyph.
        case badge(Color)
        /// Toggle: white disc with an accent glyph when on, a quiet disc when off.
        case toggle(isOn: Bool)
    }

    let systemName: String
    var style: Style
    var size: CGFloat = DesignTokens.iconWellSize

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(glyphColor)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(discColor)
                    .shadow(color: .black.opacity(isOn ? 0.15 : 0), radius: 2, y: 1)
            )
            .animation(.smooth(duration: 0.2), value: isOn)
            .accessibilityHidden(true)
    }

    private var isOn: Bool {
        if case .toggle(let isOn) = style { return isOn }
        return false
    }

    /// On an opaque white platter (Reduce Transparency, also forced by
    /// Increase Contrast) a white disc would vanish, so "on" uses the accent.
    private var solidOnState: Bool {
        colorScheme == .light && (reduceTransparency || contrast == .increased)
    }

    private var glyphColor: Color {
        switch style {
        case .badge: return .white
        case .toggle(let isOn):
            guard isOn else { return .primary }
            return solidOnState ? .white : DesignTokens.accent
        }
    }

    private var discColor: Color {
        switch style {
        case .badge(let tint): return tint
        case .toggle(let isOn):
            guard isOn else { return Color.primary.opacity(0.12) }
            return solidOnState ? DesignTokens.accent : .white
        }
    }
}
