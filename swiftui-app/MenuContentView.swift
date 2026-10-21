import SwiftUI
import AppKit

struct MenuContentView: View {
    @ObservedObject var monitor: ConnectivityMonitor
    @ObservedObject var power: PowerMonitor
    @StateObject private var login = LaunchAtLogin()
    @AppStorage(StatusPalette.colorblindDefaultsKey) private var colorblind = false
    @State private var showDrops = false

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                travelSignals
                drops
            }
            .padding(.vertical, 8)
            Divider()
            footer
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // The brand header: the icon's blue and waves, with the state up front.
    private var header: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.29, green: 0.66, blue: 1.0),
                                    Color(red: 0.11, green: 0.44, blue: 0.95),
                                    Color(red: 0.04, green: 0.25, blue: 0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            WaveShape(amplitude: 0.35).fill(Color.white.opacity(0.18))
                .frame(height: 30).frame(maxHeight: .infinity, alignment: .bottom)
            WaveShape(amplitude: 0.5).fill(Color(nsColor: .windowBackgroundColor))
                .frame(height: 18).frame(maxHeight: .infinity, alignment: .bottom)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 12).padding(.trailing, 12)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(color(for: monitor.state)).frame(width: 8, height: 8)
                    Text(pillText).font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.2)))
                .padding(.bottom, 5)
                Text(monitor.statusText)
                    .font(.system(size: 24, weight: .heavy))
                if let detail = headerDetail() {
                    Text(detail).font(.system(size: 12)).opacity(0.9)
                }
            }
            .foregroundColor(.white)
            .padding(16)
        }
        .frame(height: 132)
    }

    // Travel signals: only shown when something is off-nominal, so the
    // panel stays quiet on mains power and normal wifi.
    @ViewBuilder private var travelSignals: some View {
        if case .weak(let watts) = power.externalPower {
            signalRow("bolt.fill", "Weak power source, \(watts) W", .orange)
        }
        if monitor.isExpensive || monitor.isConstrained {
            signalRow("personalhotspot", "Hotspot or metered connection", .secondary)
        }
    }

    private func signalRow(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12))
            .foregroundColor(tint)
            .padding(.horizontal, 16).padding(.vertical, 4)
    }

    // Most of the time the header says all that matters, so drops get one
    // summary line for today; clicking it reveals the times.
    private var drops: some View {
        let drops = stretches().filter { $0.state == .offline || $0.state == .captive }
        let today = drops.filter { Calendar.current.isDateInToday($0.start) }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if today.isEmpty {
                    Image(nsImage: PeriscopeGlyph.make(size: 16, colorblind: colorblind))
                    Text("All clear today")
                } else {
                    Circle().fill(color(for: .offline)).frame(width: 9, height: 9)
                    Text(todaySummary(today))
                }
                Spacer(minLength: 8)
                if !drops.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showDrops ? 180 : 0))
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 16).padding(.vertical, 5)
            if showDrops {
                ForEach(drops.prefix(6)) { drop in
                    HStack(spacing: 8) {
                        Circle().fill(color(for: drop.state)).frame(width: 7, height: 7)
                        Text(label(for: drop.state))
                        Spacer(minLength: 8)
                        Text("\(timeRange(drop.start, drop.end)) · \(formatDuration((drop.end ?? Date()).timeIntervalSince(drop.start)))")
                            .monospacedDigit()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 16).padding(.vertical, 2)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !drops.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.15)) { showDrops.toggle() }
        }
    }

    // "2 drops today · 5m offline"
    private func todaySummary(_ today: [Stretch]) -> String {
        let total = today.reduce(0) { $0 + (($1.end ?? Date()).timeIntervalSince($1.start)) }
        let count = today.count == 1 ? "1 drop today" : "\(today.count) drops today"
        return "\(count) · \(formatDuration(total)) offline"
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                monitor.refresh()
            } label: {
                Text("Check Now").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color(red: 0.04, green: 0.52, blue: 1.0)) // brand blue, not the accent colour

            Menu {
                Toggle("Launch at Login", isOn: Binding(
                    get: { login.enabled },
                    set: { login.setEnabled($0) }
                ))
                Toggle("Colorblind-Friendly Colors", isOn: $colorblind)
                Divider()
                Button("Open Network Settings") { openNetworkSettings() }
                if !monitor.history.isEmpty {
                    Button("Clear History") { monitor.clearHistory() }
                }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Settings")
            .padding(.horizontal, 6)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit UpNow")
            .padding(.horizontal, 4)
        }
        .padding(12)
    }

    private var pillText: String {
        switch monitor.state {
        case .online: return "All good"
        case .offline: return "No connection"
        case .captive: return "Sign in to the Wi-Fi"
        case .checking: return "Checking"
        }
    }

    // "for 2h 26m · 23 ms", or whichever part is known.
    private func headerDetail() -> String? {
        var parts: [String] = []
        if let current = stretches().first, current.end == nil, current.state == monitor.state {
            parts.append("for \(formatDuration(Date().timeIntervalSince(current.start)))")
        }
        if let latency = monitor.latencyText { parts.append(latency) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

// A single soft wave across the bottom of the header, like the app icon.
private struct WaveShape: Shape {
    var amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.height * 0.5
        let rise = rect.height * amplitude
        path.move(to: CGPoint(x: 0, y: mid))
        path.addCurve(to: CGPoint(x: rect.width * 0.5, y: mid),
                      control1: CGPoint(x: rect.width * 0.17, y: mid - rise),
                      control2: CGPoint(x: rect.width * 0.33, y: mid + rise))
        path.addCurve(to: CGPoint(x: rect.width, y: mid),
                      control1: CGPoint(x: rect.width * 0.67, y: mid - rise),
                      control2: CGPoint(x: rect.width * 0.83, y: mid + rise))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
