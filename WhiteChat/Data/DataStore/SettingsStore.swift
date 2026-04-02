import Foundation
import SwiftUI

enum ThemeMode: String, CaseIterable {
    case dark, light

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }

    var displayName: String {
        switch self {
        case .dark: return L("settings_theme_dark")
        case .light: return L("settings_theme_light")
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case russian = "ru"

    static func detectSystem() -> AppLanguage {
        Locale.current.language.languageCode?.identifier == "ru" ? .russian : .english
    }
}

/// Persistent settings storage using UserDefaults — matches Android DataStore keys
final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: "theme_mode") }
    }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "app_language") }
    }
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: "onboarding_completed") }
    }
    @Published var accountEmail: String {
        didSet { defaults.set(accountEmail, forKey: "account_email") }
    }
    @Published var accountPassword: String {
        didSet { defaults.set(accountPassword, forKey: "account_password") }
    }
    @Published var accountProvider: String {
        didSet { defaults.set(accountProvider, forKey: "account_provider") }
    }
    @Published var displayName: String {
        didSet { defaults.set(displayName, forKey: "account_name") }
    }

    init() {
        self.themeMode = ThemeMode(rawValue: defaults.string(forKey: "theme_mode") ?? "") ?? .dark
        self.language = AppLanguage(rawValue: defaults.string(forKey: "app_language") ?? "") ?? AppLanguage.detectSystem()
        self.onboardingCompleted = defaults.bool(forKey: "onboarding_completed")
        self.accountEmail = defaults.string(forKey: "account_email") ?? ""
        self.accountPassword = defaults.string(forKey: "account_password") ?? ""
        self.accountProvider = defaults.string(forKey: "account_provider") ?? ""
        let savedName = defaults.string(forKey: "account_name") ?? ""
        let email = defaults.string(forKey: "account_email") ?? ""
        if savedName.isEmpty && !email.isEmpty {
            self.displayName = email.components(separatedBy: "@").first ?? email
        } else {
            self.displayName = savedName
        }

        // Verify keys exist
        verifyKeysExist()
    }

    private func verifyKeysExist() {
        if onboardingCompleted {
            let keyDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("keys")
            let publicKey = keyDir.appendingPathComponent("public.asc")
            if !FileManager.default.fileExists(atPath: publicKey.path) {
                onboardingCompleted = false
            }
        }
    }

    func resetAccount() {
        let keyDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("keys")
        try? FileManager.default.removeItem(at: keyDir)

        onboardingCompleted = false
        accountEmail = ""
        accountPassword = ""
        accountProvider = ""
        displayName = ""
    }
}

/// Localization helper
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
