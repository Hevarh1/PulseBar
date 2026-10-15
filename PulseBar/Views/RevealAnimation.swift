import SwiftUI

private struct DashboardRevealedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False while the floating dashboard is hidden or closing; sections fade
    /// in as a short cascade when it turns true. True by default (popover path).
    var dashboardRevealed: Bool {
        get { self[DashboardRevealedKey.self] }
        set { self[DashboardRevealedKey.self] = newValue }
    }
}

extension View {
    /// Fades and settles this section in as step `order` of the opening cascade.
    func revealOnOpen(order: Int) -> some View {
        modifier(RevealModifier(order: order))
    }
}

private struct RevealModifier: ViewModifier {
    let order: Int

    @Environment(\.dashboardRevealed) private var revealed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed || reduceMotion ? 0 : -6)
            .animation(animation, value: revealed)
    }

    private var animation: Animation {
        if !revealed { return .easeIn(duration: 0.12) }
        if reduceMotion { return .easeOut(duration: 0.2) }
        return .spring(response: 0.42, dampingFraction: 0.85).delay(Double(order) * 0.035)
    }
}
