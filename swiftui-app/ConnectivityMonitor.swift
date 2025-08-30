import Foundation
import Network

enum OnlineState: String {
    case checking
    case online
    case offline
    case captive // network reachable but internet likely blocked/portal
}

final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var state: OnlineState = .checking
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var history: [HistoryEntry] = []

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")
    private var lastPath: NWPath?
    private var probeTask: Task<Void, Never>? = nil
    private var tickerTask: Task<Void, Never>? = nil

    struct HistoryEntry: Identifiable {
        let id = UUID()
        let date: Date
        let state: OnlineState
    }

    init() {
        start()
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lastPath = path
            // When link is up, actively probe; otherwise mark offline immediately.
            if path.status == .satisfied {
                DispatchQueue.main.async {
                    self.state = .checking
                }
                self.startProbe()
            } else {
                DispatchQueue.main.async {
                    self.cancelProbe()
                    self.state = .offline
                    self.lastUpdated = Date()
                    self.record(.offline)
                }
            }
        }
        monitor.start(queue: queue)
        startTicker()
    }

    func stop() {
        monitor.cancel()
        stopTicker()
    }

    func refresh() {
        // Manual check: if link is up, run probe; otherwise show offline.
        if lastPath?.status == .satisfied {
            DispatchQueue.main.async { self.state = .checking }
            startProbe()
        } else {
            DispatchQueue.main.async {
                self.cancelProbe()
                self.state = .offline
                self.lastUpdated = Date()
                self.record(.offline)
            }
        }
    }

    private func startProbe() {
        cancelProbe()
        probeTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.performProbe()
            await MainActor.run {
                switch result {
                case .success:
                    self.state = .online
                    self.record(.online)
                case .captive:
                    self.state = .captive
                    self.record(.captive)
                case .failed:
                    self.state = .offline
                    self.record(.offline)
                }
                self.lastUpdated = Date()
            }
        }
    }

    private func cancelProbe() {
        probeTask?.cancel()
        probeTask = nil
    }

    private func startTicker() {
        stopTicker()
        tickerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                await MainActor.run {
                    self.refresh()
                }
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private enum ProbeResult { case success, captive, failed }

    // Perform connectivity probe per original behavior:
    // HEAD https://apple.com, if it fails, HEAD https://cloudflare.com. Both fail => offline; otherwise online.
    private func performProbe() async -> ProbeResult {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3.0
        config.timeoutIntervalForResource = 3.0
        config.waitsForConnectivity = false
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        let session = URLSession(configuration: config)

        @Sendable func head(_ urlString: String) async -> Bool {
            guard let url = URL(string: urlString) else { return false }
            var req = URLRequest(url: url)
            req.httpMethod = "HEAD"
            req.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (_, response) = try await session.data(for: req)
                // Treat any HTTP response as success (common portals may return 30x/200)
                if response is HTTPURLResponse { return true }
                return false
            } catch {
                return false
            }
        }

        if await head("https://apple.com") { return .success }
        if await head("https://cloudflare.com") { return .success }
        return .failed
    }

    @MainActor
    private func record(_ newState: OnlineState) {
        // Do not record transient checking states
        guard newState != .checking else { return }
        history.insert(HistoryEntry(date: Date(), state: newState), at: 0)
        if history.count > 10 { history.removeLast(history.count - 10) }
    }

    @MainActor
    func clearHistory() {
        history.removeAll()
    }

    var menuBarSymbolName: String {
        switch state {
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .captive:
            return "exclamationmark.triangle"
        case .online:
            return "wifi"
        case .offline:
            return "wifi.slash"
        }
    }

    var statusText: String {
        switch state {
        case .checking:
            return "Checking…"
        case .captive:
            return "Login required"
        case .online:
            return "Online"
        case .offline:
            return "Offline"
        }
    }
}
