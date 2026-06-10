import SwiftUI

@main
struct UpNowApp: App {
    @StateObject private var monitor: ConnectivityMonitor
    @StateObject private var announcer: StatusAnnouncer
    @State private var isInserted: Bool = true

    init() {
        let monitor = ConnectivityMonitor()
        _monitor = StateObject(wrappedValue: monitor)
        _announcer = StateObject(wrappedValue: StatusAnnouncer(monitor: monitor))
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $isInserted) {
            MenuContentView(monitor: monitor)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: StatusIconImage.make(for: monitor.state))
                    .renderingMode(.original) // keep colors
                if let text = announcer.text {
                    Text(text)
                }
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
