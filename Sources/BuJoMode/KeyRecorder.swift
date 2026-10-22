import SwiftUI
import AppKit

/// An NSButton that, while "recording", captures the next key + modifiers the
/// user presses (including Hyper combos and Command shortcuts) and reports it.
final class RecorderButton: NSButton {
    var onCapture: ((Hotkey) -> Void)?

    var hotkey: Hotkey = .unset { didSet { refresh() } }
    private var recording = false { didSet { refresh() } }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        recording.toggle()
        if recording { window?.makeFirstResponder(self) }
        else { window?.makeFirstResponder(nil) }
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        capture(event)
    }

    // Capture Command-based combos too (they'd otherwise be swallowed as key equivalents).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        capture(event)
        return true
    }

    private func capture(_ event: NSEvent) {
        // Escape cancels without changing the binding.
        if event.keyCode == 53 {
            recording = false
            window?.makeFirstResponder(nil)
            return
        }
        let mods = UInt64(event.modifierFlags.rawValue) & Hotkey.modifierMask
        let hk = Hotkey(keyCode: Int(event.keyCode), modifiers: mods)
        hotkey = hk
        onCapture?(hk)
        recording = false
        window?.makeFirstResponder(nil)
    }

    private func refresh() {
        title = recording ? "Press keys… (Esc to cancel)" : (hotkey.isSet ? hotkey.display : "Click to set")
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }
}

/// SwiftUI wrapper around RecorderButton.
struct KeyRecorder: NSViewRepresentable {
    @Binding var hotkey: Hotkey

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.hotkey = hotkey
        button.onCapture = { hk in hotkey = hk }
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        if nsView.hotkey != hotkey { nsView.hotkey = hotkey }
    }
}
