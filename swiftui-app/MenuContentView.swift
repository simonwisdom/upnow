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
                if let latency = monitor.latencyText {
                    Text("· \(latency)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let ts = monitor.lastUpdated {
                Text("Last checked: \(formatted(ts))")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

            // Condensed history preview: colored dots + relative times
            VStack(alignment: .leading, spacing: 2) {
                // Single-line emoji row with inline chevron (oldest → now)
                (
                    Text(condensedEmojiLine() + " ") +
                    Text(Image(systemName: "chevron.right")).font(.caption2).foregroundColor(.secondary)
                )
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("History, most recent at right")
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

            // Asks for an admin password (pmset needs root); state updates via
            // the system power-state notification once the change lands.
            Toggle(isOn: Binding(
                get: { power.lowPowerModeEnabled },
                set: { power.setLowPowerMode($0) }
            )) {
                Text("Low Power Mode")
            }
            .disabled(power.isTogglingLowPowerMode)

            Toggle(isOn: Binding(
                get: { login.enabled },
                set: { login.setEnabled($0) }
            )) {
                Text("Launch at Login")
            }

            Toggle(isOn: $colorblind) {
                Text("Colorblind-Friendly Colors")
            }

            Button("Open Network Settings") {
                openNetworkSettings()
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

    private func formatted(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // Build up to 5 states: up to 4 from history (oldest-first among most-recent subset) + current state as last ("now")
    private func recentStates() -> [OnlineState] {
        let recent = Array(monitor.history.prefix(4)) // newest-first subset
        let oldestFirst = recent.reversed().map { $0.state }
        return oldestFirst + [monitor.state]
    }

    private func condensedEmojiLine() -> String {
        recentStates().map { StatusPalette.emoji(for: $0, colorblind: colorblind) }.joined(separator: " ")
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
