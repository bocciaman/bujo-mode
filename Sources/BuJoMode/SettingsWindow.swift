import AppKit
import SwiftUI

/// Hosts the Shortcuts editor in a real, focusable NSWindow. Using our own window
/// (instead of SwiftUI's `Settings` scene) lets us force the window to become key
/// — which a menu-bar-only (LSUIElement) app otherwise won't do, leaving the key
/// recorder unable to receive keystrokes.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        // Temporarily become a regular app so the window can take focus.
        NSApp.setActivationPolicy(.regular)

        if window == nil {
            let root = SettingsView(store: AppController.shared.bindings,
                                    state: AppController.shared.state)
            let hosting = NSHostingController(rootView: root)
            let win = NSWindow(contentViewController: hosting)
            win.title = "BuJo Mode — Shortcuts"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.center()
            window = win
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        // Return to menu-bar-only when the editor closes.
        NSApp.setActivationPolicy(.accessory)
    }
}
