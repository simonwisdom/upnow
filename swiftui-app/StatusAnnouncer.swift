import Combine
import Foundation

// Publishes a short-lived text label shown next to the menu bar icon when
// connectivity transitions (e.g. "Offline", "Back online"). The label clears
// itself after a few seconds; the icon alone keeps showing the steady state.
@MainActor
final class StatusAnnouncer: ObservableObject {
    @Published private(set) var text: String? = nil

    private var lastState: OnlineState?
    private var cancellable: AnyCancellable?
    private var clearTask: Task<Void, Never>?
    private let displaySeconds: UInt64 = 4

    init(monitor: ConnectivityMonitor) {
        cancellable = monitor.$state
            .filter { $0 != .checking }
            .removeDuplicates()
            .sink { [weak self] newState in
                self?.stateDidChange(to: newState)
            }
    }

    private func stateDidChange(to newState: OnlineState) {
        defer { lastState = newState }
        // No announcement for the first state observed after launch.
        guard lastState != nil, lastState != newState else { return }
        show(label(for: newState))
    }

    private func label(for state: OnlineState) -> String {
        switch state {
        case .offline: return "Offline"
        case .captive: return "Wi-Fi login needed"
        case .online: return "Back online"
        case .checking: return "" // filtered out upstream
        }
    }

    private func show(_ message: String) {
        clearTask?.cancel()
        text = message
        clearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: (self?.displaySeconds ?? 4) * 1_000_000_000)
            if Task.isCancelled { return }
            self?.text = nil
        }
    }
}
