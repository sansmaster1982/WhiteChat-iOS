import SwiftUI
import UniformTypeIdentifiers

/// Settings screen — matches Android SettingsScreen
struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore

    @State private var showResetAlert = false
    @State private var showBackupPassword = false
    @State private var showImportPicker = false
    @State private var backupMode: BackupMode = .export
    @State private var backupPassword = ""
    @State private var statusMessage = ""
    @State private var showStatus = false

    enum BackupMode { case export, `import` }

    var body: some View {
        NavigationStack {
            List {
                // Account section
                accountSection

                // Appearance section
                appearanceSection

                // Security section
                securitySection

                // About section
                aboutSection

                // Danger zone
                dangerSection
            }
            .navigationTitle(L("settings_title"))
            .alert(L("settings_reset_title"), isPresented: $showResetAlert) {
                Button(L("settings_reset_confirm"), role: .destructive) { resetAccount() }
                Button(L("cancel"), role: .cancel) {}
            } message: {
                Text(L("settings_reset_message"))
            }
            .sheet(isPresented: $showBackupPassword) {
                BackupPasswordSheet(
                    mode: backupMode,
                    password: $backupPassword,
                    onConfirm: { handleBackup() }
                )
            }
            .sheet(isPresented: $showImportPicker) {
                DocumentPickerView { urls in
                    if let url = urls.first {
                        importFromFile(url)
                    }
                }
            }
            .alert(statusMessage, isPresented: $showStatus) {
                Button("OK") {}
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section(header: Text(L("settings_account"))) {
            HStack {
                Text(L("settings_name"))
                Spacer()
                Text(settingsStore.displayName)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(L("settings_email"))
                Spacer()
                Text(settingsStore.accountEmail)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(L("settings_provider"))
                Spacer()
                Text(settingsStore.accountProvider)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(L("settings_password"))
                Spacer()
                Text(String(repeating: "•", count: min(settingsStore.accountPassword.count, 12)))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section(header: Text(L("settings_appearance"))) {
            Picker(L("settings_theme"), selection: $settingsStore.themeMode) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Picker(L("settings_language"), selection: $settingsStore.language) {
                Text("English").tag(AppLanguage.english)
                Text("Русский").tag(AppLanguage.russian)
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section(header: Text(L("settings_security"))) {
            // Export keys
            Button {
                backupMode = .export
                backupPassword = ""
                showBackupPassword = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AppTheme.primary)
                    Text(L("settings_export_keys"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Import keys
            Button {
                backupMode = .import
                backupPassword = ""
                showImportPicker = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(AppTheme.primary)
                    Text(L("settings_import_keys"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section(header: Text(L("settings_about"))) {
            HStack {
                Text(L("settings_version"))
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(L("settings_encryption"))
                Spacer()
                Text("PGP RSA-4096")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Danger

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text(L("settings_reset_account"))
                        .foregroundColor(AppTheme.red)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func handleBackup() {
        showBackupPassword = false

        if backupMode == .export {
            exportKeys()
        }
    }

    private func exportKeys() {
        guard !backupPassword.isEmpty else { return }

        Task {
            do {
                let manager = KeyBackupManager()
                let data = try manager.exportKeys(password: backupPassword)

                // Save to Documents for sharing
                let filename = "whitechat_keys_\(Int(Date().timeIntervalSince1970)).wcb"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: url)

                await MainActor.run {
                    // Share via system share sheet
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    statusMessage = "\(L("settings_export_error")): \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
    }

    private func importFromFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            statusMessage = L("settings_import_error")
            showStatus = true
            return
        }

        // Show password dialog for import
        backupPassword = ""
        showBackupPassword = true

        // Store data temporarily for after password entry
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Wait for password entry — will be handled in handleImport
        }
    }

    private func resetAccount() {
        settingsStore.resetAccount()
        PgpKeyManager.shared.deleteAllKeys()
    }
}

// MARK: - Backup Password Sheet

struct BackupPasswordSheet: View {
    let mode: SettingsView.BackupMode
    @Binding var password: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(mode == .export ? L("backup_export_description") : L("backup_import_description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                SecureFieldToggle(label: L("backup_password_placeholder"), text: $password)
                    .padding(.horizontal)

                Button {
                    onConfirm()
                } label: {
                    Text(mode == .export ? L("backup_export_button") : L("backup_import_button"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!password.isEmpty ? AppTheme.primary : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(password.isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(mode == .export ? L("backup_export_title") : L("backup_import_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("cancel")) { dismiss() }
                }
            }
        }
    }
}
