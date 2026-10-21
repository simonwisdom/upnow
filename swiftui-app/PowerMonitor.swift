import Foundation
import IOKit.ps

// Watches the external power adapter.
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

    // Below this a source can't sustain the machine under load, so it drains
    // (or barely charges) the battery even though macOS calls it "AC Power".
    private static let weakSourceMaxWatts = 60

    private var powerSourceRunLoopSource: CFRunLoopSource?

    init() {
        readAdapter()
        watchPowerSourceChanges()
    }

    deinit {
        if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .defaultMode)
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
