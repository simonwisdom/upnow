import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var enabled: Bool = false
    private let helperIdentifier = "com.example.UpNow.LoginItem"

    init() {
        refresh()
    }

    func refresh() {
        let service = SMAppService.loginItem(identifier: helperIdentifier)
        enabled = (service.status == .enabled)
    }

    func setEnabled(_ on: Bool) {
        let service = SMAppService.loginItem(identifier: helperIdentifier)
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // In a production app, surface this error to the user.
        }
        refresh()
    }
}
