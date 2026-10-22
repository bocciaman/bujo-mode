import CoreGraphics
import Carbon.HIToolbox

/// Synthetic keystrokes, used only when AX writes aren't available.
enum Synth {

    /// Sentinel stamped on every event we post, so our own event tap ignores
    /// them (otherwise a synthetic Return would re-enter the tap → infinite loop).
    static let sentinel: Int64 = 0x42754A6F  // "BuJo"

    private static func source() -> CGEventSource? {
        CGEventSource(stateID: .combinedSessionState)
    }

    /// Press and release a virtual key.
    static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let src = source()
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: sentinel)
            e.post(tap: .cghidEventTap)
        }
    }

    /// Insert an arbitrary string at the current insertion point via a Unicode
    /// keyboard event (works for the BuJo glyphs without keycode mapping).
    static func type(_ string: String) {
        let src = source()
        let units = Array(string.utf16)
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) {
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            down.setIntegerValueField(.eventSourceUserData, value: sentinel)
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
            up.setIntegerValueField(.eventSourceUserData, value: sentinel)
            up.post(tap: .cghidEventTap)
        }
    }
}
