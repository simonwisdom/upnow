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
                    // The native menu puts this on its own line, so no leading "·".
                    Text(detail)
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

            // Being online is the normal state, so History leads with how
            // long it has lasted and then lists only the drops.
            Menu("History") {
                Text(currentStretchLine())
                Divider()
                let drops = stretches().filter { $0.state == .offline || $0.state == .captive }
                if drops.isEmpty {
                    // Inline in the text: the native menu drops a Label's icon.
                    Text(Image(nsImage: PeriscopeGlyph.make(size: 16, colorblind: colorblind)))
                        + Text("  All clear, nothing spotted")
                } else {
                    ForEach(drops) { drop in
                        Text(dropLine(drop))
                            .foregroundColor(color(for: drop.state))
                    }
                }
                if !monitor.history.isEmpty {
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
        // The formatter says "in 0 sec." for a check that just finished.
        if Date().timeIntervalSince(date) < 5 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // A run of one state. end is nil while it is still going.
    private struct Stretch: Identifiable {
        let state: OnlineState
        let start: Date
        let end: Date?
        var id: Date { start }
    }

    // History (newest first) with back-to-back entries in the same state,
    // which an app restart splits, joined into one stretch.
    private func stretches() -> [Stretch] {
        var result: [Stretch] = []
        for entry in monitor.history {
            if let last = result.last, last.state == entry.state {
                result[result.count - 1] = Stretch(state: entry.state, start: entry.date, end: last.end)
            } else {
                result.append(Stretch(state: entry.state, start: entry.date, end: entry.endDate))
            }
        }
        return result
    }

    // "Online for 2h 14m"
    private func currentStretchLine() -> String {
        guard let current = stretches().first, current.end == nil else {
            return monitor.statusText
        }
        return "\(label(for: current.state)) for \(formatDuration(Date().timeIntervalSince(current.start)))"
    }

    // "🔴 Offline   4:12 – 4:15 PM · 3m"
    private func dropLine(_ drop: Stretch) -> String {
        let symbol = StatusPalette.emoji(for: drop.state, colorblind: colorblind)
        let duration = formatDuration((drop.end ?? Date()).timeIntervalSince(drop.start))
        return "\(symbol) \(label(for: drop.state))   \(timeRange(drop.start, drop.end)) · \(duration)"
    }

    // "4:12 – 4:15 PM", "Yesterday 9:40 – 9:41 AM", "4:12 PM – now"
    private func timeRange(_ start: Date, _ end: Date?) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(start) {
            day = ""
        } else if calendar.isDateInYesterday(start) {
            day = "Yesterday "
        } else {
            day = start.formatted(.dateTime.weekday(.abbreviated)) + " "
        }
        guard let end else {
            return day + start.formatted(date: .omitted, time: .shortened) + " – now"
        }
        return day + (start..<max(start, end)).formatted(.interval.hour().minute())
    }

    private func label(for state: OnlineState) -> String {
        switch state {
        case .online: return "Online"
        case .offline: return "Offline"
        case .checking: return "Checking"
        case .captive: return "Wi-Fi login"
        }
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
