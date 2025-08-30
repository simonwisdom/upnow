import SwiftUI
import AppKit
import ServiceManagement

struct MenuContentView: View {
    @ObservedObject var monitor: ConnectivityMonitor
    @StateObject private var login = LaunchAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(colorForState())
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(monitor.statusText)
                    .font(.headline)
            }

            if let ts = monitor.lastUpdated {
                Text("Last checked: \(formatted(ts))")
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
                    ForEach(Array(monitor.history.prefix(10))) { entry in
                        Text(historyLine(entry))
                            .foregroundColor(textColor(for: entry.state))
                    }
                    Divider()
                    Button("Clear History") {
                        monitor.clearHistory()
                    }
                }
            }

            Toggle(isOn: Binding(
                get: { login.enabled },
                set: { login.setEnabled($0) }
            )) {
                Text("Launch at Login")
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

    private func colorForState() -> Color {
        switch monitor.state {
        case .online: return .green
        case .offline: return .red
        case .checking: return .yellow
        case .captive: return .orange
        }
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

    // kept for potential future string-based rendering
    private func condensedEmojiLine() -> String {
        recentStates().map { emoji(for: $0) }.joined(separator: " ")
    }

    private func emoji(for state: OnlineState) -> String {
        switch state {
        case .online: return "🟢"
        case .offline: return "🟥"
        case .checking: return "🟡"
        case .captive: return "⚠️"
        }
    }

    // no-op

    private func historyLine(_ entry: ConnectivityMonitor.HistoryEntry) -> String {
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        let when = rel.localizedString(for: entry.date, relativeTo: Date())
        let label: String
        let symbol: String
        switch entry.state {
        case .online:
            label = "Online"
            symbol = "🟢"
        case .offline:
            label = "Offline"
            symbol = "🟥"
        case .checking:
            label = "Checking"
            symbol = "🟡"
        case .captive:
            label = "Login required"
            symbol = "⚠️"
        }
        return "\(symbol) \(label) — \(when)"
    }

    private func openNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        }
    }

    private func color(for state: OnlineState) -> Color {
        switch state {
        case .online: return .green
        case .offline: return .red
        case .checking: return .yellow
        case .captive: return .orange
        }
    }

    private func textColor(for state: OnlineState) -> Color {
        switch state {
        case .online: return .green
        case .offline: return .red
        case .checking: return .yellow
        case .captive: return .orange
        }
    }
}
