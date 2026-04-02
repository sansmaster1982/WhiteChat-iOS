import SwiftUI
import CodeScanner

/// Onboarding flow — matches Android OnboardingScreen
/// Pages: Welcome → Choose Provider → IMAP Instructions → Account → Key Generation
struct OnboardingView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var currentPage = 0
    @State private var selectedProvider = -1
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isGeneratingKeys = false
    @State private var keyGenDone = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            AppTheme.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with back button
                if currentPage > 0 {
                    HStack {
                        Button {
                            withAnimation { currentPage -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Pages
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    providerPage.tag(1)
                    instructionsPage.tag(2)
                    accountPage.tag(3)
                    keyGenPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page dots
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
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.primary)

            Text("WhiteChat")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Text(L("onboarding_subtitle"))
                .font(.body)
                .foregroundColor(AppTheme.darkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text(L("onboarding_start"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Page 1: Choose Provider

    private var providerPage: some View {
        VStack(spacing: 20) {
            Text(L("onboarding_choose_provider"))
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.top, 32)

            Text(L("onboarding_choose_provider_hint"))
                .font(.body)
                .foregroundColor(AppTheme.darkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                providerButton(index: 0, name: "Yandex", icon: "envelope.fill", color: .red)
                providerButton(index: 1, name: "Mail.ru", icon: "envelope.fill", color: .blue)
                providerButton(index: 2, name: "Rambler", icon: "envelope.fill", color: .green)
                providerButton(index: 3, name: L("onboarding_other_provider"), icon: "globe", color: .gray)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func providerButton(index: Int, name: String, icon: String, color: Color) -> some View {
        Button {
            selectedProvider = index
            withAnimation { currentPage = 2 }
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)
                Text(name)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(AppTheme.darkCard)
            .cornerRadius(12)
        }
    }

    // MARK: - Page 2: IMAP Instructions

    private var instructionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("onboarding_instructions_title"))
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(instructionText)
                    .font(.body)
                    .foregroundColor(AppTheme.darkTextSecondary)
                    .padding(.horizontal, 8)

                Spacer(minLength: 20)

                Button {
                    withAnimation { currentPage = 3 }
                } label: {
                    Text(L("onboarding_instructions_done"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .cornerRadius(12)
                }
            }
            .padding(24)
        }
    }

    private var instructionText: String {
        switch selectedProvider {
        case 0: // Yandex
            return """
            1. Откройте mail.yandex.ru в браузере
            2. Настройки → Все настройки → Почтовые программы
            3. Включите «С сервера imap.yandex.ru по протоколу IMAP»
            4. Создайте пароль приложения:
               Настройки → Безопасность → Пароли приложений
            5. Нажмите «Создать пароль приложения»
            6. Выберите «Почта» → придумайте имя
            7. Скопируйте пароль — он понадобится на следующем шаге

            Важно: используйте пароль приложения, а не основной пароль!
            """
        case 1: // Mail.ru
            return """
            1. Откройте mail.ru и войдите в почту
            2. Настройки → Все настройки → Почта из других ящиков
            3. Убедитесь что IMAP включён
            4. Создайте пароль для внешних приложений:
               Настройки → Безопасность → Пароли для внешних приложений
            5. Нажмите «Добавить» → введите имя
            6. Скопируйте сгенерированный пароль

            Важно: используйте пароль приложения!
            """
        case 2: // Rambler
            return """
            1. Откройте mail.rambler.ru и войдите
            2. Настройки → Почтовые программы
            3. Включите доступ по IMAP
            4. Поставьте галочку «Разрешить доступ по IMAP»
            5. Используйте ваш обычный пароль от Rambler

            Примечание: Rambler использует обычный пароль.
            """
        default: // Other
            return """
            1. Убедитесь что IMAP включён в настройках вашей почты
            2. Создайте пароль приложения если требуется
            3. Используйте IMAP-пароль на следующем шаге

            IMAP серверы определяются автоматически по домену.
            """
        }
    }

    // MARK: - Page 3: Account (email + password + name)

    private var accountPage: some View {
        VStack(spacing: 20) {
            Text(L("onboarding_account_title"))
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.top, 32)

            VStack(spacing: 16) {
                TextField(L("onboarding_name"), text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.words)

                TextField(L("onboarding_email"), text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)

                SecureFieldToggle(label: L("onboarding_password"), text: $password)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 32)

            Text(L("onboarding_password_hint"))
                .font(.caption)
                .foregroundColor(AppTheme.darkTextSecondary)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                startKeyGeneration()
            } label: {
                Text(L("onboarding_generate_keys"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? AppTheme.primary : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!canProceed)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Page 4: Key Generation + QR

    private var keyGenPage: some View {
        VStack(spacing: 24) {
            Spacer()
            if isGeneratingKeys {
                ProgressView()
                    .scaleEffect(2)
                    .tint(AppTheme.primary)
                Text(L("onboarding_generating"))
                    .font(.title3)
                    .foregroundColor(.white)
                Text(L("onboarding_generating_hint"))
                    .font(.caption)
                    .foregroundColor(AppTheme.darkTextSecondary)
            } else if keyGenDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.green)

                Text(L("onboarding_ready"))
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // Show QR code
                if let qrString = PgpKeyManager.shared.getQRString(email: email, name: displayName) {
                    if let qrImage = generateQR(from: qrString) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }

                    Text(L("onboarding_qr_hint"))
                        .font(.caption)
                        .foregroundColor(AppTheme.darkTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    settingsStore.onboardingCompleted = true
                } label: {
                    Text(L("onboarding_continue"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - Logic

    private var canProceed: Bool {
        !email.isEmpty && !password.isEmpty && !displayName.isEmpty && email.contains("@")
    }

    private func startKeyGeneration() {
        withAnimation { currentPage = 4 }
        isGeneratingKeys = true

        Task {
            do {
                try PgpKeyManager.shared.generateKeyPair(email: email, name: displayName)

                await MainActor.run {
                    settingsStore.accountEmail = email
                    settingsStore.accountPassword = password
                    settingsStore.displayName = displayName

                    let providerNames = ["Yandex", "Mail.ru", "Rambler", "Other"]
                    settingsStore.accountProvider = selectedProvider >= 0 && selectedProvider < providerNames.count
                        ? providerNames[selectedProvider]
                        : EmailConstants.findProvider(for: email).name

                    isGeneratingKeys = false
                    keyGenDone = true
                }
            } catch {
                await MainActor.run {
                    isGeneratingKeys = false
                    errorMessage = "\(L("error")): \(error.localizedDescription)"
                    showError = true
                    currentPage = 3
                }
            }
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
