import SwiftUI
import Combine

/// App-wide toast coordinator (singleton or EnvironmentObject)
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published var current: ToastItem? = nil

    /// Global default auto-hide delay (seconds). Change this anywhere:
    /// `ToastCenter.shared.defaultDuration = 5`
    var defaultDuration: TimeInterval = 3.0

    private var cancellable: AnyCancellable?

    /// Show a toast with optional tap action.
    /// - Parameters:
    ///   - text: The message to display.
    ///   - duration: Auto-hide delay in seconds. If `nil`, uses `defaultDuration`.
    ///               If `<= 0`, the toast stays up until user taps or you call `dismiss()`.
    ///   - onTap: Optional tap handler; always dismisses first.
    func show(text: String,
              duration: TimeInterval? = nil,
              onTap: (() -> Void)? = nil)
    {
        // Build a unique toast instance so we can compare by id on auto-dismiss.
        let toast = ToastItem(text: text,
                              duration: duration ?? defaultDuration,
                              onTap: onTap)
        current = toast

        // Cancel any pending auto-dismiss from a previous toast.
        cancellable?.cancel()
        cancellable = nil

        // Determine effective timing.
        let effective = duration ?? defaultDuration
        guard effective > 0 else { return } // no auto-dismiss

        // Auto-dismiss after `effective` *only if* the same toast is still showing.
        cancellable = Just(())
            .delay(for: .seconds(effective), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                if self.current?.id == toast.id {
                    self.current = nil
                }
            }
    }

    /// Convenience for the achievements case (duration override optional).
    func showAchievementUnlock(count: Int,
                               duration: TimeInterval? = nil,
                               onTap: (() -> Void)? = nil)
    {
        let msg = (count == 1)
        ? "Achievement unlocked — Collect your coins →"
        : "\(count) achievements unlocked — Collect your coins →"
        show(text: msg, duration: duration, onTap: onTap)
    }

    /// Manually dismiss the current toast.
    func dismiss() {
        cancellable?.cancel()
        cancellable = nil
        current = nil
    }
}

/// Payload rendered by the host.
struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var duration: TimeInterval
    var onTap: (() -> Void)? = nil

    // Only compare stable fields (ignore the closure)
    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.duration == rhs.duration
    }
}
