import SwiftUI

@main
struct WhiteChatApp: App {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if settingsStore.onboardingCompleted {
                MainTabView()
                    .environmentObject(settingsStore)
                    .environmentObject(appState)
                    .preferredColorScheme(settingsStore.themeMode.colorScheme)
                    .onAppear { appState.startEmailSync(settingsStore: settingsStore) }
                    .onDisappear { appState.stopEmailSync() }
            } else {
                OnboardingView()
                    .environmentObject(settingsStore)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
