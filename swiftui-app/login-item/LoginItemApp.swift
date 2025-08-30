import SwiftUI
import AppKit

@main
struct LoginItemApp: App {
    init() {
        launchMainIfNeeded()
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    var body: some Scene {
        // No windows; background-only
        Settings { EmptyView() }
    }

    private func launchMainIfNeeded() {
        let mainBundleID = "com.example.UpNow"
        if NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleID).isEmpty {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainBundleID) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = false
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in }
            }
        }
    }
}
