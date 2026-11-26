import Foundation

/// State for the memory tile's Free button. Lives outside the view because the
/// administrator prompt takes focus, which closes the dashboard; the result is
/// still there when it reopens.
@MainActor
public final class MemoryCleaner: ObservableObject {
    public static let shared = MemoryCleaner()

    public enum Phase: Equatable {
        case idle
        case working
        case done(String)
    }

    @Published public private(set) var phase: Phase = .idle
    private var resetTask: Task<Void, Never>?

    private init() {}

    public func free() {
        guard phase != .working else { return }
        resetTask?.cancel()
        phase = .working
        Task {
            let result = await MetricsCoordinator.shared.freeUpMemory()
            switch result {
            case .freed(let bytes):
                UtilityFeedback.playSuccess()
                finish(with: Self.summary(freedBytes: bytes))
            case .cancelled:
                phase = .idle
            case .failed(let message):
                phase = .idle
                UtilityFeedback.showInfo(title: "Couldn’t Free Memory", message: message)
            }
        }
    }

    static func summary(freedBytes: UInt64) -> String {
        // Below ~50 MB the delta is sampling noise, not a result.
        guard freedBytes >= 50 * 1024 * 1024 else { return "Already lean" }
        return "Freed \(Formatters.formatBytes(freedBytes))"
    }

    private func finish(with text: String) {
        phase = .done(text)
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.phase = .idle
        }
    }
}
