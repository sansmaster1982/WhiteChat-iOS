import SwiftUI
import CodeScanner

/// Onboarding flow — EXACT copy of Android OnboardingScreen
/// Pages: 0=Welcome, 1=ChooseProvider, 2=Instructions, 3=Account, 4=KeyGen
struct OnboardingView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var currentPage = 0
    @State private var selectedProvider = -1
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isGeneratingKeys = false
    @State private var keyGenDone = false
    @State private var generatedId = ""
    @State private var errorMessage = ""
    @State private var showError = false

    private let providerSuffixes = ["@mail.ru", "@yandex.ru", "@rambler.ru"]
    private let providerNames = ["Mail.ru", "Yandex", "Rambler"]

    var body: some View {
        ZStack {
            AppTheme.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    if currentPage > 0 && currentPage < 4 {
                        Button { withAnimation { currentPage -= 1 } } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2).foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal).padding(.top, 8)
                .frame(height: 44)

                // Content
                Group {
                    switch currentPage {
                    case 0: welcomePage
                    case 1: providerPage
                    case 2: instructionsPage
                    case 3: accountPage
                    case 4: keyGenPage
                    default: EmptyView()
                    }
                }
                .animation(.easeInOut, value: currentPage)

                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(i == currentPage ? AppTheme.primary : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .alert(L("error"), isPresented: $showError) {
            Button("OK") {}
        } message: { Text(errorMessage) }
    }

    // MARK: - Page 0: Welcome
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80)).foregroundColor(AppTheme.primary)
            Text("WhiteChat").font(.largeTitle.bold()).foregroundColor(.white)
            Text(L("onboarding_subtitle"))
                .font(.body).foregroundColor(AppTheme.darkTextSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
            purpleButton(L("onboarding_start")) { currentPage = 1 }
        }
    }

    // MARK: - Page 1: Choose Provider (ONLY 3 — no "Other")
    private var providerPage: some View {
        VStack(spacing: 20) {
            Text(L("onboarding_choose_provider")).font(.title2.bold()).foregroundColor(.white).padding(.top, 32)
            Text(L("onboarding_choose_provider_hint"))
                .font(.body).foregroundColor(AppTheme.darkTextSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)

            VStack(spacing: 12) {
                providerRow(index: 0, name: "Mail.ru", icon: "envelope.fill", color: .blue)
                providerRow(index: 1, name: "Yandex", icon: "envelope.fill", color: .red)
                providerRow(index: 2, name: "Rambler", icon: "envelope.fill", color: .green)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func providerRow(index: Int, name: String, icon: String, color: Color) -> some View {
        Button {
            selectedProvider = index
            email = providerSuffixes[index] // Pre-fill suffix
            currentPage = 2
        } label: {
            HStack {
                Image(systemName: icon).foregroundColor(color).frame(width: 30)
                Text(name).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding()
            .background(AppTheme.darkCard)
            .cornerRadius(12)
        }
    }

    // MARK: - Page 2: Instructions (per provider)
    private var instructionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("onboarding_instructions_title"))
                    .font(.title2.bold()).foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(instructionTextForProvider)
                    .font(.body).foregroundColor(AppTheme.darkTextSecondary)
                    .padding(.horizontal, 8)

                Spacer(minLength: 20)
                purpleButton(L("onboarding_instructions_done")) { currentPage = 3 }
            }
            .padding(24)
        }
    }

    private var instructionTextForProvider: String {
        switch selectedProvider {
        case 0: // Mail.ru
            return """
            1. Откройте mail.ru и войдите в почту
            2. Настройки → Все настройки
            3. Почта из других ящиков → убедитесь что IMAP включён
            4. Безопасность → Пароли для внешних приложений
            5. Нажмите «Добавить» → введите имя «WhiteChat»
            6. Скопируйте сгенерированный пароль

            Используйте этот пароль на следующем шаге!
            """
        case 1: // Yandex
            return """
            1. Откройте mail.yandex.ru в браузере
            2. Настройки → Все настройки → Почтовые программы
            3. Включите «С сервера imap.yandex.ru по протоколу IMAP»
            4. Перейдите: Настройки → Безопасность → Пароли приложений
            5. Нажмите «Создать пароль приложения»
            6. Выберите «Почта» → придумайте имя «WhiteChat»
            7. Скопируйте пароль

            Важно: используйте пароль приложения, а не основной пароль!
            """
        case 2: // Rambler
            return """
            1. Откройте mail.rambler.ru и войдите
            2. Настройки → Почтовые программы
            3. Включите доступ по IMAP
            4. Поставьте галочку «Разрешить доступ»
            5. Используйте ваш обычный пароль от Rambler

            Примечание: Rambler не требует пароль приложения.
            """
        default:
            return ""
        }
    }

    // MARK: - Page 3: Account (name + email with suffix + password)
    private var accountPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(L("onboarding_account_title")).font(.title2.bold()).foregroundColor(.white).padding(.top, 16)

                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ваше имя").font(.caption).foregroundColor(.gray)
                    TextField("Ваше имя", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                }

                // Email (pre-filled with @provider.ru)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email").font(.caption).foregroundColor(.gray)
                    TextField("user\(providerSuffixes[max(0, selectedProvider)])", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                }

                // Password
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("onboarding_password")).font(.caption).foregroundColor(.gray)
                    SecureFieldToggle(label: L("onboarding_password"), text: $password)
                        .padding(.horizontal, 4).padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                }

                Text(L("onboarding_password_hint"))
                    .font(.caption).foregroundColor(AppTheme.darkTextSecondary)

                Spacer(minLength: 20)

                // Validation errors
                if !validationError.isEmpty {
                    Text(validationError).font(.caption).foregroundColor(AppTheme.red)
                }

                purpleButton(L("onboarding_generate_keys"), enabled: canProceed) {
                    if validate() { startKeyGeneration() }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    @State private var validationError = ""

    private var canProceed: Bool {
        !email.isEmpty && !password.isEmpty && !displayName.isEmpty
    }

    private func validate() -> Bool {
        let n = displayName.trimmingCharacters(in: .whitespaces)
        let e = email.trimmingCharacters(in: .whitespaces)
        if n.isEmpty {
            validationError = "Введите ваше имя"
            return false
        }
        if e.isEmpty || !e.contains("@") || e.hasPrefix("@") || e.components(separatedBy: "@").first?.isEmpty == true {
            validationError = "Введите полный email (например user\(providerSuffixes[max(0, selectedProvider)]))"
            return false
        }
        if password.isEmpty {
            validationError = "Введите пароль"
            return false
        }
        validationError = ""
        return true
    }

    // MARK: - Page 4: Key Generation
    private var keyGenPage: some View {
        VStack(spacing: 24) {
            Spacer()
            if isGeneratingKeys {
                ProgressView().scaleEffect(2).tint(AppTheme.primary)
                Text(L("onboarding_generating")).font(.title3).foregroundColor(.white)
                Text(L("onboarding_generating_hint")).font(.caption).foregroundColor(AppTheme.darkTextSecondary)
            } else if keyGenDone {
                Image(systemName: "lock.fill").font(.system(size: 60)).foregroundColor(AppTheme.primary)
                Text(L("onboarding_ready")).font(.title2.bold()).foregroundColor(.white)
                Text("Your Key ID: \(generatedId)")
                    .font(.headline).foregroundColor(AppTheme.primary)
                Text("Публичный ключ сгенерирован").font(.body).foregroundColor(AppTheme.darkTextSecondary)

                purpleButton("Начать общение") {
                    settingsStore.onboardingCompleted = true
                }
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Logic
    private func startKeyGeneration() {
        currentPage = 4
        isGeneratingKeys = true
        let cleanEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let cleanName = displayName.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                try PgpKeyManager.shared.generateKeyPair(email: cleanEmail, name: cleanName)
                let fp = PgpKeyManager.shared.getFingerprint() ?? "00000"
                let shortId = "DM-\(String(fp.suffix(5)).uppercased())"

                await MainActor.run {
                    settingsStore.accountEmail = cleanEmail
                    settingsStore.accountPassword = password
                    settingsStore.displayName = cleanName
                    settingsStore.accountProvider = providerNames[max(0, selectedProvider)]
                    generatedId = shortId
                    isGeneratingKeys = false
                    keyGenDone = true
                }
            } catch {
                await MainActor.run {
                    isGeneratingKeys = false
                    errorMessage = error.localizedDescription
                    showError = true
                    currentPage = 3
                }
            }
        }
    }

    // MARK: - Helper
    private func purpleButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding()
                .background(enabled ? AppTheme.primary : Color.gray)
                .cornerRadius(12)
        }
        .disabled(!enabled)
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }
}
