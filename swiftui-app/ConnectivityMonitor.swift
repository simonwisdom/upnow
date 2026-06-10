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
            DispatchQueue.main.async {
                self.lastPath = path
                if path.status == .satisfied {
                    // Show "checking" only if we weren't already online;
                    // otherwise re-probe silently to avoid icon flicker.
                    if self.state != .online {
                        self.state = .checking
                    }
                    self.startProbe()
                } else {
                    self.cancelProbe()
                    self.setState(.offline)
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
        check(showChecking: true)
    }

    // Run a connectivity check. Background (ticker) checks keep the current
    // state visible while probing; manual checks show "checking" feedback.
    private func check(showChecking: Bool) {
        DispatchQueue.main.async {
            if self.lastPath?.status == .satisfied {
                if showChecking {
                    self.state = .checking
                }
                self.startProbe()
            } else {
                self.cancelProbe()
                self.setState(.offline)
            }
        }
    }

    private func startProbe() {
        cancelProbe()
        probeTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.performProbe()
            // A newer probe may have superseded this one; don't apply stale results.
            if Task.isCancelled { return }
            await MainActor.run {
                switch result {
                case .success:
                    self.setState(.online)
                case .captive:
                    self.setState(.captive)
                case .failed:
                    self.setState(.offline)
                }
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
                self.check(showChecking: false)
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private enum ProbeResult { case success, captive, failed }

    // Probe endpoints with known responses over plain HTTP (what captive
    // portals intercept). An unexpected HTTP response means a portal is in
    // the way; no response at all means offline.
    private func performProbe() async -> ProbeResult {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3.0
        config.timeoutIntervalForResource = 3.0
        config.waitsForConnectivity = false
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        enum EndpointResult { case expected, unexpected, unreachable }

        @Sendable func fetch(_ urlString: String,
                             isExpected: @Sendable (HTTPURLResponse, Data) -> Bool) async -> EndpointResult {
            guard let url = URL(string: urlString) else { return .unreachable }
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else { return .unreachable }
                return isExpected(http, data) ? .expected : .unexpected
            } catch {
                return .unreachable
            }
        }

        // Apple's captive-check endpoint returns a tiny page containing "Success".
        let apple = await fetch("http://captive.apple.com/hotspot-detect.html") { _, data in
            String(data: data, encoding: .utf8)?.contains("Success") == true
        }
        if apple == .expected { return .success }

        // Fallback: must return exactly 204.
        let gstatic = await fetch("http://www.gstatic.com/generate_204") { http, _ in
            http.statusCode == 204
        }
        switch gstatic {
        case .expected:
            return .success
        case .unexpected:
            return .captive
        case .unreachable:
            return apple == .unexpected ? .captive : .failed
        }
    }

    @MainActor
    private func setState(_ newState: OnlineState) {
        state = newState
        lastUpdated = Date()
        record(newState)
    }

    @MainActor
    private func record(_ newState: OnlineState) {
        // Do not record transient checking states
        guard newState != .checking else { return }
        // Only record transitions; repeated identical results are noise.
        if history.first?.state == newState { return }
        history.insert(HistoryEntry(date: Date(), state: newState), at: 0)
        if history.count > 10 { history.removeLast(history.count - 10) }
    }

    @MainActor
    func clearHistory() {
        history.removeAll()
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
