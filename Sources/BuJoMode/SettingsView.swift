import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: BindingStore
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shortcuts")
                .font(.title2).bold()

            HStack(spacing: 6) {
                Circle()
                    .fill(state.axTrusted ? Color.green : Color.orange)
                    .frame(width: 9, height: 9)
                Text(state.axTrusted
                     ? "Accessibility granted — shortcuts active"
                     : "Accessibility not granted — shortcuts won't fire yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !state.axTrusted {
                    Button("Grant…") { AppController.shared.requestTrust() }
                        .controlSize(.small)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                row("Toggle BuJo mode", binding: $store.value.toggle)
                Divider().gridCellColumns(2)
                ForEach(SymbolKind.allCases) { kind in
                    row("\(BuJoConfig.symbols.string(kind))  \(kind.label)",
                        binding: swapBinding(kind))
                }
            }

            Divider()

            HStack {
                Text("Press a field, then press the keys you want (Hyper works).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Reset to defaults") { store.resetToDefaults() }
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func row(_ label: String, binding: Binding<Hotkey>) -> some View {
        GridRow {
            Text(label)
            KeyRecorder(hotkey: binding)
                .frame(width: 200, height: 24)
        }
    }

    private func swapBinding(_ kind: SymbolKind) -> Binding<Hotkey> {
        Binding(
            get: { store.value.swap(for: kind) },
            set: { store.value.setSwap($0, for: kind) }
        )
    }
}
