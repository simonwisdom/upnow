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
            NSWorkspace.shared.launchApplication(withBundleIdentifier: mainBundleID, options: [.default], additionalEventParamDescriptor: nil, launchIdentifier: nil)
        }
    }
}
