import SwiftUI

@main
struct VpnClientApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark) // Sleek modern dark mode by default
        }
    }
}
