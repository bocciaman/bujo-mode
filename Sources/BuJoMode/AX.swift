import ApplicationServices

/// A snapshot of the currently focused editable text element.
struct AXText {
    let element: AXUIElement
    let value: String
    let caret: Int        // UTF-16 offset of the insertion point (selection start)
    let selectionLength: Int
}

/// Thin wrapper over the Accessibility API for reading/writing the focused field.
enum AX {

    /// Whether this process is trusted for Accessibility. Pass `prompt: true` to
    /// surface the system "grant access" dialog.
    @discardableResult
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Read the focused text element, its string value, and caret/selection.
    /// Returns nil when there is no focused *text* element we can drive
    /// (e.g. Finder, a non-AX web/Electron field, or an app that hides its value).
    static func focusedText() -> AXText? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef,
              CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        let element = focused as! AXUIElement

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef as? String
        else { return nil }

        // Default caret to end-of-text if the field doesn't report a selection.
        var caret = (value as NSString).length
        var selLength = 0
        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let r = rangeRef,
           CFGetTypeID(r) == AXValueGetTypeID() {
            var cf = CFRange()
            if AXValueGetValue(r as! AXValue, .cfRange, &cf) {
                caret = cf.location
                selLength = cf.length
            }
        }

        return AXText(element: element, value: value, caret: caret, selectionLength: selLength)
    }

    /// Apply a text edit via AX: select the target range, replace it, then place
    /// the caret. Returns false if the element refuses AX writes (fall back to
    /// synthetic keystrokes in that case).
    @discardableResult
    static func apply(_ edit: TextEdit, to element: AXUIElement) -> Bool {
        var range = CFRange(location: edit.replaceRange.location, length: edit.replaceRange.length)
        guard let rangeValue = AXValueCreate(.cfRange, &range) else { return false }

        guard AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue) == .success
        else { return false }

        guard AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, edit.replacement as CFString) == .success
        else { return false }

        var caretRange = CFRange(location: edit.caret, length: 0)
        if let caretValue = AXValueCreate(.cfRange, &caretRange) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue)
        }
        return true
    }
}
