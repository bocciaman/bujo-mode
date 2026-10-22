import Foundation
import Carbon.HIToolbox

/// The line-leading symbols. All are a single UTF-16 unit, which keeps caret
/// math simple, but the code does not assume that — change any of them to taste.
enum SymbolKind: String, Codable, CaseIterable, Identifiable {
    case action     // • task
    case note       // – note
    case moody      // = moody / feelings
    case event      // ○ event
    case migrated   // > task migrated
    case scheduled  // < task scheduled
    case priority   // * priority

    var id: String { rawValue }

    /// Human-readable name for menus and preferences.
    var label: String {
        switch self {
        case .action:    return "Action"
        case .note:      return "Note"
        case .moody:     return "Feelings"
        case .event:     return "Event"
        case .migrated:  return "Migrated"
        case .scheduled: return "Scheduled"
        case .priority:  return "Priority"
        }
    }
}

struct Symbols {
    /// •  U+2022 — Action / task
    var action = "\u{2022}"
    /// –  U+2013 en dash — Note.  <-- easiest one to swap for another dash.
    var note = "\u{2013}"
    /// =  Moody / Feelings
    var moody = "="
    /// ○  U+25CB — Event
    var event = "\u{25CB}"
    /// >  Task Migrated
    var migrated = ">"
    /// <  Task Scheduled
    var scheduled = "<"
    /// *  Priority
    var priority = "*"

    func string(_ kind: SymbolKind) -> String {
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

    var all: [String] { [action, note, moody, event, migrated, scheduled, priority] }
}

enum BuJoConfig {
    /// Change symbols in one place.
    static var symbols = Symbols()

    /// Return / keypad-Enter — the keys we auto-continue (matched with no modifiers).
    static let returnKeyCodes: Set<Int64> = [
        Int64(kVK_Return),            // 36
        Int64(kVK_ANSI_KeypadEnter),  // 76
    ]
}
