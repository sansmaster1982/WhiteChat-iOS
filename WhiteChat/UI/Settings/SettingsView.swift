import SwiftUI
import UniformTypeIdentifiers

/// Settings screen — EXACT copy of Android SettingsScreen
/// Editable: name (dialog), email+password (dialog), password visibility toggle
struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var showResetAlert = false
    @State private var showEditName = false
    @State private var showEditEmail = false
    @State private var showBackupPassword = false
    @State private var showImportPicker = false
    @State private var backupMode: BackupMode = .export
    @State private var backupPassword = ""
    @State private var statusMessage = ""
    @State private var showStatus = false
    @State private var passwordVisible = false

    // Edit dialog states
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var editPassword = ""

    enum BackupMode { case export, `import` }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                appearanceSection
                securitySection
                aboutSection
                dangerSection
            }
            .navigationTitle(L("settings_title"))
            // Edit Name Dialog
            .alert("Изменить имя", isPresented: $showEditName) {
                TextField("Ваше имя", text: $editName)
                Button("Сохранить") {
                    let trimmed = editName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { settingsStore.displayName = trimmed }
                }
                Button(L("cancel"), role: .cancel) {}
            }
            // Edit Email Dialog
            .alert("Изменить email", isPresented: $showEditEmail) {
                TextField("Email", text: $editEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                SecureField(L("onboarding_password"), text: $editPassword)
                Button("Сохранить") {
                    let e = editEmail.trimmingCharacters(in: .whitespaces).lowercased()
                    if !e.isEmpty && e.contains("@") && !editPassword.isEmpty {
                        settingsStore.accountEmail = e
                        settingsStore.accountPassword = editPassword
                        let provider = EmailConstants.findProvider(for: e)
                        settingsStore.accountProvider = provider.name
                    }
                }
                Button(L("cancel"), role: .cancel) {}
            }
            .alert(L("settings_reset_title"), isPresented: $showResetAlert) {
                Button(L("settings_reset_confirm"), role: .destructive) { resetAccount() }
                Button(L("cancel"), role: .cancel) {}
            } message: { Text(L("settings_reset_message")) }
            .sheet(isPresented: $showBackupPassword) {
                BackupPasswordSheet(mode: backupMode, password: $backupPassword, onConfirm: { handleBackup() })
            }
            .sheet(isPresented: $showImportPicker) {
                DocumentPickerView { urls in
                    if let url = urls.first { importFromFile(url) }
                }
            }
            .alert(statusMessage, isPresented: $showStatus) { Button("OK") {} }
        }
    }

    // MARK: - Account (editable)
    private var accountSection: some View {
        Section(header: Text(L("settings_account"))) {
            // Name — editable
            HStack {
                Text(L("settings_name"))
                Spacer()
                Text(settingsStore.displayName.isEmpty ? "—" : settingsStore.displayName)
                    .foregroundColor(.secondary)
                Button {
                    editName = settingsStore.displayName
                    showEditName = true
                } label: {
                    Image(systemName: "pencil").foregroundColor(AppTheme.primary)
                }
            }

            // Email — editable
            HStack {
                Text(L("settings_email"))
                Spacer()
                Text(settingsStore.accountEmail.isEmpty ? "—" : settingsStore.accountEmail)
                    .foregroundColor(.secondary)
                Button {
                    editEmail = settingsStore.accountEmail
                    editPassword = settingsStore.accountPassword
                    showEditEmail = true
                } label: {
                    Image(systemName: "pencil").foregroundColor(AppTheme.primary)
                }
            }

            // Provider — read only
            HStack {
                Text(L("settings_provider"))
                Spacer()
                Text(settingsStore.accountProvider.isEmpty ? "—" : settingsStore.accountProvider)
                    .foregroundColor(.secondary)
            }

            // Password — visibility toggle
            HStack {
                Text(L("settings_password"))
                Spacer()
                if passwordVisible {
                    Text(settingsStore.accountPassword)
                        .foregroundColor(.secondary)
                } else {
                    Text(String(repeating: "•", count: min(settingsStore.accountPassword.count, 12)))
                        .foregroundColor(.secondary)
                }
                Button {
                    passwordVisible.toggle()
                } label: {
                    Image(systemName: passwordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Appearance
    private var appearanceSection: some View {
        Section(header: Text(L("settings_appearance"))) {
            Picker(L("settings_theme"), selection: $settingsStore.themeMode) {
                ForEach(ThemeMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
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
            Button {
                backupMode = .export; backupPassword = ""; showBackupPassword = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up").foregroundColor(AppTheme.primary)
                    Text(L("settings_export_keys"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
            }
            Button {
                backupMode = .import; backupPassword = ""; showImportPicker = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down").foregroundColor(AppTheme.primary)
                    Text(L("settings_import_keys"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        Section(header: Text(L("settings_about"))) {
            HStack { Text(L("settings_version")); Spacer(); Text("1.0.0").foregroundColor(.secondary) }
            HStack { Text(L("settings_encryption")); Spacer(); Text("PGP RSA-4096").foregroundColor(.secondary) }
        }
    }

    // MARK: - Danger
    private var dangerSection: some View {
        Section {
            Button(role: .destructive) { showResetAlert = true } label: {
                HStack { Spacer(); Text(L("settings_reset_account")).foregroundColor(AppTheme.red); Spacer() }
            }
        }
    }

    // MARK: - Actions
    private func handleBackup() {
        showBackupPassword = false
        if backupMode == .export { exportKeys() }
    }

    private func exportKeys() {
        guard !backupPassword.isEmpty else { return }
        Task {
            do {
                let data = try KeyBackupManager().exportKeys(password: backupPassword)
                let filename = "whitechat_keys_\(Int(Date().timeIntervalSince1970)).wcb"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: url)
                await MainActor.run {
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            } catch {
                await MainActor.run { statusMessage = "\(L("settings_export_error")): \(error.localizedDescription)"; showStatus = true }
            }
        }
    }

    private func importFromFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { statusMessage = L("settings_import_error"); showStatus = true; return }
        backupPassword = ""
        showBackupPassword = true
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
                    .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                SecureFieldToggle(label: L("backup_password_placeholder"), text: $password)
                    .padding(.horizontal)
                Button {
                    onConfirm()
                } label: {
                    Text(mode == .export ? L("backup_export_button") : L("backup_import_button"))
                        .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                        .background(!password.isEmpty ? AppTheme.primary : Color.gray).cornerRadius(12)
                }
                .disabled(password.isEmpty).padding(.horizontal)
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(mode == .export ? L("backup_export_title") : L("backup_import_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("cancel")) { dismiss() } } }
        }
    }
}
