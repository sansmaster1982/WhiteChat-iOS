import Foundation
import Combine

/// Global app state: email sync, foreground/background tracking
final class AppState: ObservableObject {
    @Published var isInForeground = true

    private var emailSyncService: EmailSyncService?

    func startEmailSync(settingsStore: SettingsStore) {
        guard !settingsStore.accountEmail.isEmpty,
              !settingsStore.accountPassword.isEmpty else { return }

        let service = EmailSyncService(
            email: settingsStore.accountEmail,
            password: settingsStore.accountPassword
        )
        self.emailSyncService = service
        service.start()
    }

    func stopEmailSync() {
        emailSyncService?.stop()
        emailSyncService = nil
    }

    func setForeground(_ fg: Bool) {
        isInForeground = fg
        emailSyncService?.setForeground(fg)
    }
}
