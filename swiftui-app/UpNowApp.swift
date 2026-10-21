import SwiftUI

@main
struct UpNowApp: App {
    @StateObject private var monitor: ConnectivityMonitor
    @StateObject private var power: PowerMonitor
    @StateObject private var announcer: StatusAnnouncer
    @State private var isInserted: Bool = true
    @AppStorage(StatusPalette.colorblindDefaultsKey) private var colorblind = false

    init() {
        let monitor = ConnectivityMonitor()
        _monitor = StateObject(wrappedValue: monitor)
        _power = StateObject(wrappedValue: PowerMonitor())
        _announcer = StateObject(wrappedValue: StatusAnnouncer(monitor: monitor))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { WelcomeWindow.showIfFirstLaunch() }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $isInserted) {
            MenuContentView(monitor: monitor, power: power)
        } label: {
            HStack(spacing: 4) {
                // The periscope pops up for the few seconds "Back online" shows.
                if monitor.state == .online, announcer.text != nil {
                    Image(nsImage: PeriscopeGlyph.make(colorblind: colorblind))
                        .renderingMode(.original)
                } else {
                    Image(nsImage: StatusIconImage.make(for: monitor.state,
                                                        metered: monitor.isExpensive || monitor.isConstrained,
                                                        colorblind: colorblind))
                        .renderingMode(.original) // keep colors
                }
                if let text = announcer.text {
                    Text(text)
                }
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
