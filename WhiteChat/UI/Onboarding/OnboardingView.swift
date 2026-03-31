import SwiftUI
import CodeScanner

/// Onboarding flow — account setup + key generation
/// Matches Android OnboardingScreen
struct OnboardingView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var currentPage = 0
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isGeneratingKeys = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            AppTheme.darkBackground.ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                accountPage.tag(1)
                generatingPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .alert(L("error"), isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Page 1: Welcome

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
            .padding(.bottom, 48)
        }
    }

    // MARK: - Page 2: Account

    private var accountPage: some View {
        VStack(spacing: 20) {
            Text(L("onboarding_account_title"))
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.top, 48)

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
                    .textFieldStyle(.roundedBorder)
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
            .padding(.bottom, 48)
        }
    }

    // MARK: - Page 3: Generating

    private var generatingPage: some View {
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
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppTheme.green)
                Text(L("onboarding_ready"))
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }

    // MARK: - Logic

    private var canProceed: Bool {
        !email.isEmpty && !password.isEmpty && !displayName.isEmpty && email.contains("@")
    }

    private func startKeyGeneration() {
        withAnimation { currentPage = 2 }
        isGeneratingKeys = true

        Task {
            do {
                try PgpKeyManager.shared.generateKeyPair(email: email, name: displayName)

                await MainActor.run {
                    settingsStore.accountEmail = email
                    settingsStore.accountPassword = password
                    settingsStore.displayName = displayName
                    settingsStore.accountProvider = EmailConstants.findProvider(for: email).name
                    settingsStore.onboardingCompleted = true
                    isGeneratingKeys = false
                }
            } catch {
                await MainActor.run {
                    isGeneratingKeys = false
                    errorMessage = error.localizedDescription
                    showError = true
                    currentPage = 1
                }
            }
        }
    }
}
