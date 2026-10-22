import SwiftUI

/// Observable UI state for the menu-bar item and preferences.
final class AppState: ObservableObject {
    @Published var modeOn = false
    @Published var axTrusted = false
    @Published var tapActive = false
    /// Set when the user turns mode on but the tap isn't active yet.
    @Published var needsPermissionToWork = false
}
