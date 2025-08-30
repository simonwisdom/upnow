import SwiftUI

@main
struct UpNowApp: App {
    @StateObject private var monitor = ConnectivityMonitor()
    @State private var isInserted: Bool = true

    var body: some Scene {
        MenuBarExtra(isInserted: $isInserted) {
            MenuContentView(monitor: monitor)
        } label: {
            Image(nsImage: StatusIconImage.make(for: monitor.state))
                .renderingMode(.original) // keep colors
        }
        .menuBarExtraStyle(.menu)
    }
}
