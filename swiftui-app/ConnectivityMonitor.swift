import Foundation
import Network

enum OnlineState: String, Codable {
    case checking
    case online
    case offline
    case captive // network reachable but internet likely blocked/portal
}

final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var state: OnlineState = .checking
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var latency: TimeInterval? = nil

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")
    private var lastPath: NWPath?
    private var probeTask: Task<Void, Never>? = nil
    private var tickerTask: Task<Void, Never>? = nil

    // Adaptive polling: back off while results stay the same, snap back on
    // any transition. NWPathMonitor still triggers immediate checks.
    private var checkInterval: TimeInterval = 20
    private let baseCheckInterval: TimeInterval = 20
    private let maxCheckInterval: TimeInterval = 120

    private static let historyDefaultsKey = "connectivityHistory"
    private static let lastCheckDefaultsKey = "lastCheckDate"

    struct HistoryEntry: Identifiable, Codable {
        var id = UUID()
        let date: Date
        var endDate: Date? = nil // nil while the state is still current
        let state: OnlineState
    }

    init() {
        history = Self.loadHistory()
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
                case .success(let latency):
                    self.latency = latency
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
            while !Task.isCancelled {
                guard let self else { return }
                let interval = await MainActor.run { self.checkInterval }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { return }
                self.check(showChecking: false)
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private enum ProbeResult { case success(latency: TimeInterval), captive, failed }

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
                             isExpected: @Sendable (HTTPURLResponse, Data) -> Bool) async -> (result: EndpointResult, elapsed: TimeInterval) {
            guard let url = URL(string: urlString) else { return (.unreachable, 0) }
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            let start = Date()
            do {
                let (data, response) = try await session.data(for: req)
                let elapsed = Date().timeIntervalSince(start)
                guard let http = response as? HTTPURLResponse else { return (.unreachable, elapsed) }
                return (isExpected(http, data) ? .expected : .unexpected, elapsed)
            } catch {
                return (.unreachable, 0)
            }
        }

        // Apple's captive-check endpoint returns a tiny page containing "Success".
        let apple = await fetch("http://captive.apple.com/hotspot-detect.html") { _, data in
            String(data: data, encoding: .utf8)?.contains("Success") == true
        }
        if apple.result == .expected { return .success(latency: apple.elapsed) }

        // Fallback: must return exactly 204.
        let gstatic = await fetch("http://www.gstatic.com/generate_204") { http, _ in
            http.statusCode == 204
        }
        switch gstatic.result {
        case .expected:
            return .success(latency: gstatic.elapsed)
        case .unexpected:
            return .captive
        case .unreachable:
            return apple.result == .unexpected ? .captive : .failed
        }
    }

    @MainActor
    private func setState(_ newState: OnlineState) {
        let previous = history.first?.state
        state = newState
        if newState != .online { latency = nil }
        lastUpdated = Date()
        // Remember when we last checked so a relaunch can close out the
        // current history entry instead of letting it span app downtime.
        UserDefaults.standard.set(lastUpdated, forKey: Self.lastCheckDefaultsKey)
        record(newState)
        updateCheckInterval(stable: previous == newState)
    }

    @MainActor
    private func updateCheckInterval(stable: Bool) {
        if stable {
            checkInterval = min(checkInterval * 2, maxCheckInterval)
        } else {
            checkInterval = baseCheckInterval
            // Re-arm so the next check uses the short interval immediately.
            startTicker()
        }
    }

    @MainActor
    private func record(_ newState: OnlineState) {
        // Do not record transient checking states
        guard newState != .checking else { return }
        // Only record transitions; repeated identical results are noise.
        // Entries closed at relaunch don't dedupe, so each run starts fresh.
        if let first = history.first, first.state == newState, first.endDate == nil { return }
        if !history.isEmpty, history[0].endDate == nil {
            history[0].endDate = Date()
        }
        history.insert(HistoryEntry(date: Date(), state: newState), at: 0)
        if history.count > 10 { history.removeLast(history.count - 10) }
        saveHistory()
    }

    @MainActor
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private static func loadHistory() -> [HistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: historyDefaultsKey),
              var entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return []
        }
        // Close the entry that was current when the app last ran, so its
        // duration ends at the last check rather than spanning downtime.
        if let first = entries.first, first.endDate == nil {
            let lastCheck = UserDefaults.standard.object(forKey: lastCheckDefaultsKey) as? Date
            entries[0].endDate = max(first.date, lastCheck ?? first.date)
        }
        return entries
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyDefaultsKey)
    }

    // e.g. "43 ms"; only meaningful while online.
    var latencyText: String? {
        guard state == .online, let latency else { return nil }
        return "\(Int((latency * 1000).rounded())) ms"
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
