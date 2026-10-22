import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// A recordable hotkey: a key plus a set of modifier flags. Modifier bits use the
/// device-independent layout shared by CGEventFlags and NSEvent.ModifierFlags
/// (shift=1<<17, control=1<<18, option=1<<19, command=1<<20), so a combo recorded
/// from an NSEvent matches an event seen by the CGEventTap without translation.
struct Hotkey: Codable, Equatable {
    var keyCode: Int
    var modifiers: UInt64

    static let modifierMask: UInt64 =
        CGEventFlags.maskShift.rawValue |
        CGEventFlags.maskControl.rawValue |
        CGEventFlags.maskAlternate.rawValue |
        CGEventFlags.maskCommand.rawValue

    /// All four modifiers held together = the Caps-Lock "Hyper" key.
    static let hyper: UInt64 = modifierMask

    static let unset = Hotkey(keyCode: -1, modifiers: 0)
    var isSet: Bool { keyCode >= 0 }

    func matches(keyCode kc: Int64, flags: CGEventFlags) -> Bool {
        guard isSet else { return false }
        return Int(kc) == keyCode && (flags.rawValue & Hotkey.modifierMask) == modifiers
    }

    /// e.g. "Hyper-B", "⌃⌥1", "F5".
    var display: String {
        guard isSet else { return "—" }
        let mods: String
        if modifiers == Hotkey.hyper {
            mods = "Hyper-"
        } else {
            var s = ""
            if modifiers & CGEventFlags.maskControl.rawValue != 0 { s += "⌃" }
            if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { s += "⌥" }
            if modifiers & CGEventFlags.maskShift.rawValue != 0 { s += "⇧" }
            if modifiers & CGEventFlags.maskCommand.rawValue != 0 { s += "⌘" }
            mods = s
        }
        return mods + Hotkey.keyName(keyCode)
    }

    static func keyName(_ code: Int) -> String {
        keyNames[code] ?? "key\(code)"
    }

    private static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    /// Convert to Carbon modifier flags (kept for reference / possible reuse).
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if modifiers & CGEventFlags.maskControl.rawValue != 0 { m |= UInt32(controlKey) }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { m |= UInt32(optionKey) }
        if modifiers & CGEventFlags.maskShift.rawValue != 0 { m |= UInt32(shiftKey) }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0 { m |= UInt32(cmdKey) }
        return m
    }
}

/// The full set of bindings, persisted as one JSON blob.
struct Bindings: Codable, Equatable {
    var toggle: Hotkey
    var action: Hotkey
    var note: Hotkey
    var moody: Hotkey
    var event: Hotkey
    var migrated: Hotkey
    var scheduled: Hotkey
    var priority: Hotkey

    func swap(for kind: SymbolKind) -> Hotkey {
        switch kind {
        case .action:    return action
        case .note:      return note
        case .moody:     return moody
        case .event:     return event
        case .migrated:  return migrated
        case .scheduled: return scheduled
        case .priority:  return priority
        }
    }

    mutating func setSwap(_ hk: Hotkey, for kind: SymbolKind) {
        switch kind {
        case .action:    action = hk
        case .note:      note = hk
        case .moody:     moody = hk
        case .event:     event = hk
        case .migrated:  migrated = hk
        case .scheduled: scheduled = hk
        case .priority:  priority = hk
        }
    }

    /// Defaults = the current Hyper bindings ("leave my shortcut keys as they are").
    static let defaults = Bindings(
        toggle:    Hotkey(keyCode: kVK_ANSI_B, modifiers: Hotkey.hyper),
        action:    Hotkey(keyCode: kVK_ANSI_1, modifiers: Hotkey.hyper),
        note:      Hotkey(keyCode: kVK_ANSI_2, modifiers: Hotkey.hyper),
        moody:     Hotkey(keyCode: kVK_ANSI_3, modifiers: Hotkey.hyper),
        event:     Hotkey(keyCode: kVK_ANSI_4, modifiers: Hotkey.hyper),
        migrated:  Hotkey(keyCode: kVK_ANSI_5, modifiers: Hotkey.hyper),
        scheduled: Hotkey(keyCode: kVK_ANSI_6, modifiers: Hotkey.hyper),
        priority:  Hotkey(keyCode: kVK_ANSI_7, modifiers: Hotkey.hyper)
    )
}

/// Observable, persisted store for the bindings. The event tap reads `value`
/// live on every keystroke, so changes take effect immediately — no re-register.
final class BindingStore: ObservableObject {
    private static let key = "bindings.v1"

    @Published var value: Bindings {
        didSet { persist() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(Bindings.self, from: data) {
            value = decoded
        } else {
            value = .defaults
        }
    }

    func resetToDefaults() {
        value = .defaults
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
