import SwiftUI
import AppKit

// A menu bar app opens no window, so on first launch people can't tell
// anything happened. Show one small welcome, once, with the periscope rising
// out of the water, and point them at the menu bar.
@MainActor
enum WelcomeWindow {
    private static let shownDefaultsKey = "welcomeShown"
    private static var window: NSWindow?

    static func showIfFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: shownDefaultsKey) else { return }
        UserDefaults.standard.set(true, forKey: shownDefaultsKey)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 330),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeView { window.close() })
        window.center()
        self.window = window
        // A menu bar app isn't frontmost at launch, so bring the window up
        // regardless rather than waiting for the app to be activated.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

private struct WelcomeView: View {
    let done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var risen = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .offset(y: risen ? 0 : 60)
                    .opacity(risen ? 1 : 0)
            }
            .frame(width: 140, height: 140)
            .clipped()

            Text("UpNow is keeping watch")
                .font(.title3.weight(.semibold))
            Text("Look for the dot in your menu bar. Green means you're online.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Got it", action: done)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 24)
        .frame(width: 340)
        .onAppear {
            if reduceMotion {
                risen = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.3)) { risen = true }
            }
        }
    }
}
