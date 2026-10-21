import SwiftUI
import AppKit
import ServiceManagement

struct MenuContentView: View {
    @ObservedObject var monitor: ConnectivityMonitor
    @ObservedObject var power: PowerMonitor
    @StateObject private var login = LaunchAtLogin()
    @AppStorage(StatusPalette.colorblindDefaultsKey) private var colorblind = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color(for: monitor.state))
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(monitor.statusText)
                    .font(.headline)
                if let detail = statusDetail() {
                    Text("· \(detail)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Travel signals: only shown when something is off-nominal, so the
            // menu stays quiet on mains power and normal wifi.
            if case .weak(let watts) = power.externalPower {
                Text("⚡️ Weak power source — \(watts) W")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            if monitor.isExpensive || monitor.isConstrained {
                Text("📶 Hotspot / metered connection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Button("Check Now") {
                monitor.refresh()
            }

            Menu("History") {
                if monitor.history.isEmpty {
                    Text("No history yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(monitor.history) { entry in
                        // An open entry (no endDate) is still ongoing.
                        Text(historyLine(entry, endDate: entry.endDate ?? Date()))
                            .foregroundColor(color(for: entry.state))
                    }
                    Divider()
                    Button("Clear History") {
                        monitor.clearHistory()
                    }
                }
            }

            Menu("Settings") {
                Toggle(isOn: Binding(
                    get: { login.enabled },
                    set: { login.setEnabled($0) }
                )) {
                    Text("Launch at Login")
                }

                Toggle(isOn: $colorblind) {
                    Text("Colorblind-Friendly Colors")
                }

                Divider()

                Button("Open Network Settings") {
                    openNetworkSettings()
                }
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(minWidth: 220)
    }

    // "24 ms · checked 1 min. ago", or whichever half is known.
    private func statusDetail() -> String? {
        var parts: [String] = []
        if let latency = monitor.latencyText { parts.append(latency) }
        if let ts = monitor.lastUpdated { parts.append("checked \(formatted(ts))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func formatted(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func historyLine(_ entry: ConnectivityMonitor.HistoryEntry, endDate: Date) -> String {
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        let when = rel.localizedString(for: entry.date, relativeTo: Date())
        let label: String
        switch entry.state {
        case .online: label = "Online"
        case .offline: label = "Offline"
        case .checking: label = "Checking"
        case .captive: label = "Login required"
        }
        let symbol = StatusPalette.emoji(for: entry.state, colorblind: colorblind)
        let duration = formatDuration(endDate.timeIntervalSince(entry.date))
        return "\(symbol) \(label) for \(duration) — \(when)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        if minutes < 60 {
            let s = total % 60
            return s > 0 ? "\(minutes)m \(s)s" : "\(minutes)m"
        }
        let hours = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(hours)h \(m)m" : "\(hours)h"
    }

    private func openNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        }
    }

    private func color(for state: OnlineState) -> Color {
        Color(nsColor: StatusPalette.color(for: state, colorblind: colorblind))
    }
}
