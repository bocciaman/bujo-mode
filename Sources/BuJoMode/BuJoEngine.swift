import Foundation

/// A single edit to apply to a text field, expressed in UTF-16 units so it maps
/// directly onto the Accessibility API's `CFRange` (which is UTF-16 based).
struct TextEdit {
    /// Range within the full text to replace.
    let replaceRange: NSRange
    /// String to put in its place.
    let replacement: String
    /// Absolute UTF-16 offset where the caret should land afterwards.
    let caret: Int
}

/// Result of pressing Return on a line while BuJo mode is on.
enum ContinueResult {
    case none              // not a bulleted line — let Return behave normally
    case insert(TextEdit)  // continue the bullet on a new line
    case breakOut(TextEdit) // empty bullet — clear it and leave a plain line
}

/// Pure text transforms. Everything here is deterministic and side-effect free.
enum BuJoEngine {

    private static let newline = unichar(10)
    private static let space = unichar(32)

    /// The range of the line containing `caret` (excluding the trailing newline).
    static func lineRange(_ text: NSString, caret: Int) -> NSRange {
        let len = text.length
        let c = max(0, min(caret, len))
        var start = c
        while start > 0 && text.character(at: start - 1) != newline { start -= 1 }
        var end = c
        while end < len && text.character(at: end) != newline { end += 1 }
        return NSRange(location: start, length: end - start)
    }

    /// If `line` begins with one of the configured symbols, return it plus whether
    /// a single space follows.
    static func leadingSymbol(_ line: NSString, symbols: Symbols) -> (symbol: String, hasSpace: Bool)? {
        for sym in symbols.all {
            let symLen = (sym as NSString).length
            guard symLen > 0, line.length >= symLen else { continue }
            if line.substring(to: symLen) == sym {
                let hasSpace = line.length > symLen && line.character(at: symLen) == space
                return (sym, hasSpace)
            }
        }
        return nil
    }

    /// Return pressed: continue / break-out logic.
    static func continueResult(text: String, caret: Int, symbols: Symbols) -> ContinueResult {
        let ns = text as NSString
        let c = max(0, min(caret, ns.length))
        let lr = lineRange(ns, caret: c)
        let line = ns.substring(with: lr) as NSString

        guard let found = leadingSymbol(line, symbols: symbols) else { return .none }
        let symLen = (found.symbol as NSString).length

        // Skip the symbol and one optional following space, then see if anything is left.
        var afterIdx = symLen
        if afterIdx < line.length && line.character(at: afterIdx) == space { afterIdx += 1 }
        let remainder = line.length > afterIdx ? line.substring(from: afterIdx) : ""
        let isEmptyBullet = remainder.trimmingCharacters(in: .whitespaces).isEmpty

        if isEmptyBullet {
            // Delete the leading "symbol( space)" so the line becomes plain/empty.
            let edit = TextEdit(
                replaceRange: NSRange(location: lr.location, length: afterIdx),
                replacement: "",
                caret: lr.location
            )
            return .breakOut(edit)
        } else {
            // Insert newline + same symbol + space at the caret.
            let insertion = "\n" + found.symbol + " "
            let edit = TextEdit(
                replaceRange: NSRange(location: c, length: 0),
                replacement: insertion,
                caret: c + (insertion as NSString).length
            )
            return .insert(edit)
        }
    }

    /// Swap key pressed: set/replace this line's leading symbol, preserving its text.
    static func swapEdit(text: String, caret: Int, to kind: SymbolKind, symbols: Symbols) -> TextEdit {
        let ns = text as NSString
        let c = max(0, min(caret, ns.length))
        let lr = lineRange(ns, caret: c)
        let line = ns.substring(with: lr) as NSString
        let newSym = symbols.string(kind)

        if let found = leadingSymbol(line, symbols: symbols) {
            // Replace just the symbol character, keeping the space and the text.
            let symLen = (found.symbol as NSString).length
            let newLen = (newSym as NSString).length
            let delta = newLen - symLen
            let newCaret = c >= lr.location + symLen ? c + delta : c
            return TextEdit(
                replaceRange: NSRange(location: lr.location, length: symLen),
                replacement: newSym,
                caret: newCaret
            )
        } else {
            // No symbol yet — prepend "symbol space" at the line start.
            let insertion = newSym + " "
            let insLen = (insertion as NSString).length
            return TextEdit(
                replaceRange: NSRange(location: lr.location, length: 0),
                replacement: insertion,
                caret: c + insLen
            )
        }
    }

    /// Turning mode ON: insert "• " at the caret to start an Action line.
    static func insertOnEnable(caret: Int, symbols: Symbols) -> TextEdit {
        let insertion = symbols.action + " "
        return TextEdit(
            replaceRange: NSRange(location: max(0, caret), length: 0),
            replacement: insertion,
            caret: max(0, caret) + (insertion as NSString).length
        )
    }
}
