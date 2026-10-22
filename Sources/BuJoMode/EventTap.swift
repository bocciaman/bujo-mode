import CoreGraphics
import CoreFoundation

/// Owns the CGEventTap that intercepts Return + swap keys. Created lazily on the
/// first "mode ON" and then enabled/disabled — while disabled it intercepts
/// nothing, so the keyboard is completely normal when BuJo mode is off.
final class EventTapController {

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Return `true` to swallow the event, `false` to pass it through.
    var onEvent: ((CGEventType, CGEvent) -> Bool)?

    /// Create the tap (once) and enable it. Returns false if the OS refuses —
    /// almost always because Accessibility permission hasn't been granted yet.
    @discardableResult
    func start() -> Bool {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return true
        }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            return false
        }
        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func setEnabled(_ enabled: Bool) {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: enabled)
    }

    /// The system disables taps that are too slow or that fire during certain
    /// secure-input situations; re-enable when that happens.
    func reEnable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    var isEnabled: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }
}

/// C-compatible tap callback. Recovers the controller from `refcon` and delegates.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<EventTapController>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        controller.reEnable()
        return Unmanaged.passUnretained(event)
    }

    if let handler = controller.onEvent, handler(type, event) {
        return nil  // swallow
    }
    return Unmanaged.passUnretained(event)
}
