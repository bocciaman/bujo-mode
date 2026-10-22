import SwiftUI

struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var bindings = AppController.shared.bindings

    var body: some View {
        Button(state.modeOn ? "Turn BuJo Mode OFF" : "Turn BuJo Mode ON") {
            AppController.shared.toggleMode()
        }

        Text(state.modeOn ? "Status: ON" : "Status: off")

        Divider()

        if !state.axTrusted {
            Text("⚠︎ Accessibility permission required")
            Button("Request Accessibility Access…") {
                AppController.shared.requestTrust()
            }
            Button("Open Accessibility Settings…") {
                AppController.shared.openAccessibilitySettings()
            }
            Divider()
        }

        Text("Toggle:  \(bindings.value.toggle.display)")
        ForEach(SymbolKind.allCases) { kind in
            Text("\(BuJoConfig.symbols.string(kind))  \(kind.label)   \(bindings.value.swap(for: kind).display)")
        }

        Divider()

        Button("Shortcuts…") {
            AppController.shared.openSettings()
        }
        Button("Quit BuJo Mode") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
