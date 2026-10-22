import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Central coordinator: owns state, the (always-on) event tap, and the bindings,
/// and contains the continue/swap decision logic.
final class AppController {

    static let shared = AppController()

    let state = AppState()
    let bindings = BindingStore()
    private let tap = EventTapController()
    private var trustTimer: Timer?

    private init() {}

    // MARK: Lifecycle

    func start() {
        tap.onEvent = { [weak self] type, event in
            self?.handleTapEvent(type: type, event: event) ?? false
        }
        refreshTrust(prompt: false)
        ensureTap()
    }

    /// Bring the tap up if we're trusted; otherwise poll until permission is granted.
    private func ensureTap() {
        if state.axTrusted {
            let ok = tap.start()
            tap.setEnabled(ok)
            state.tapActive = ok
            stopTrustPolling()
        } else {
            state.tapActive = false
            startTrustPolling()
        }
    }

    private func startTrustPolling() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshTrust(prompt: false)
            if self.state.axTrusted { self.ensureTap() }
        }
    }

    private func stopTrustPolling() {
        trustTimer?.invalidate()
        trustTimer = nil
    }

    // MARK: Accessibility trust

    func refreshTrust(prompt: Bool) {
        state.axTrusted = AX.isTrusted(prompt: prompt)
    }

    func requestTrust() {
        refreshTrust(prompt: true)
        ensureTap()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Preferences window

    func openSettings() {
        SettingsWindowController.shared.show()
    }

    // MARK: Mode toggle

    func toggleMode() {
        setMode(!state.modeOn)
    }

    func setMode(_ on: Bool) {
        state.modeOn = on
        state.needsPermissionToWork = on && !state.tapActive
        if on { insertActionBullet() }
    }

    private func insertActionBullet() {
        if let ax = AX.focusedText() {
            let edit = BuJoEngine.insertOnEnable(caret: ax.caret, symbols: BuJoConfig.symbols)
            if AX.apply(edit, to: ax.element) { return }
        }
        Synth.type(BuJoConfig.symbols.action + " ")
    }

    // MARK: Event tap handling

    /// Returns true to swallow the event.
    private func handleTapEvent(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .keyDown else { return false }
        // Ignore keystrokes we synthesized ourselves.
        if event.getIntegerValueField(.eventSourceUserData) == Synth.sentinel { return false }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let b = bindings.value

        // Toggle works whether mode is on or off.
        if b.toggle.matches(keyCode: keyCode, flags: flags) {
            toggleMode()
            return true
        }

        guard state.modeOn else { return false }

        // Swap keys.
        for kind in SymbolKind.allCases where b.swap(for: kind).matches(keyCode: keyCode, flags: flags) {
            performSwap(kind)
            return true
        }

        // Return / keypad-Enter with no modifiers → auto-continue.
        let noModifiers = (flags.rawValue & Hotkey.modifierMask) == 0
        if noModifiers && BuJoConfig.returnKeyCodes.contains(keyCode) {
            return performReturn()
        }

        return false
    }

    /// Returns true if we handled Return (swallow), false to let it type normally.
    private func performReturn() -> Bool {
        guard let ax = AX.focusedText() else { return false }

        switch BuJoEngine.continueResult(text: ax.value, caret: ax.caret, symbols: BuJoConfig.symbols) {
        case .none:
            return false

        case .insert(let edit):
            if AX.apply(edit, to: ax.element) { return true }
            Synth.postKey(CGKeyCode(kVK_Return))
            let tail = (edit.replacement as NSString).substring(from: 1)  // drop leading "\n"
            Synth.type(tail)
            return true

        case .breakOut(let edit):
            if AX.apply(edit, to: ax.element) { return true }
            for _ in 0..<edit.replaceRange.length {
                Synth.postKey(CGKeyCode(kVK_Delete))
            }
            return true
        }
    }

    private func performSwap(_ kind: SymbolKind) {
        guard let ax = AX.focusedText() else { return }
        let edit = BuJoEngine.swapEdit(text: ax.value, caret: ax.caret, to: kind, symbols: BuJoConfig.symbols)
        AX.apply(edit, to: ax.element)
    }
}
