import Foundation
import IOKit.ps

// Watches the external power adapter and system Low Power Mode.
// macOS reports any USB-C source as "AC Power", so a weak power bank looks
// like mains power to the system; the negotiated wattage tells them apart.
@MainActor
final class PowerMonitor: ObservableObject {
    enum ExternalPower: Equatable {
        case none              // running on the internal battery
        case weak(watts: Int)  // power bank or other low-watt source
        case mains(watts: Int) // a real wall charger
    }

    @Published private(set) var externalPower: ExternalPower = .none
    @Published private(set) var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published private(set) var isTogglingLowPowerMode = false

    // Below this a source can't sustain the machine under load, so it drains
    // (or barely charges) the battery even though macOS calls it "AC Power".
    private static let weakSourceMaxWatts = 60

    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var lowPowerModeObserver: NSObjectProtocol?

    init() {
        readAdapter()
        watchPowerSourceChanges()
        lowPowerModeObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    deinit {
        if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .defaultMode)
        }
        if let lowPowerModeObserver {
            NotificationCenter.default.removeObserver(lowPowerModeObserver)
        }
    }

    // Flip system Low Power Mode via pmset, which needs root; macOS shows its
    // standard administrator-password prompt. If the user cancels, pmset does
    // nothing and the published state simply stays as it was.
    func setLowPowerMode(_ enabled: Bool) {
        guard !isTogglingLowPowerMode else { return }
        isTogglingLowPowerMode = true
        let script = "do shell script \"pmset -a lowpowermode \(enabled ? 1 : 0)\" with administrator privileges"
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
            process.waitUntilExit()
            await MainActor.run { [weak self] in
                self?.isTogglingLowPowerMode = false
                self?.lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    private func watchPowerSourceChanges() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in monitor.readAdapter() }
        }, context)?.takeRetainedValue() else { return }
        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func readAdapter() {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any],
              let watts = details[kIOPSPowerAdapterWattsKey as String] as? Int else {
            externalPower = .none
            return
        }
        externalPower = watts <= Self.weakSourceMaxWatts ? .weak(watts: watts) : .mains(watts: watts)
    }
}
