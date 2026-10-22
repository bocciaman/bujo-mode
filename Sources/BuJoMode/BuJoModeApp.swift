import SwiftUI
import AppKit

@main
struct BuJoModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var state = AppController.shared.state

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
        } label: {
            Image(systemName: state.modeOn ? "list.bullet.circle.fill" : "list.bullet.circle")
                .accessibilityLabel(state.modeOn ? "BuJo Mode on" : "BuJo Mode off")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppController.shared.start()
    }
}
