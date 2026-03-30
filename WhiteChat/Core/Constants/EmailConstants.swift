import Foundation

/// Email protocol constants — must match Android EmailConstants exactly
enum EmailConstants {
    static let subjectPrefix = "DM-Encrypted"
    static let headerName = "X-DarkMessage"
    static let headerValue = "v2"
    static let darkMessageFolder = "DarkMessage"

    /// Email provider configuration
    struct Provider {
        let name: String
        let domains: [String]
        let imapHost: String
        let imapPort: Int
        let smtpHost: String
        let smtpPort: Int
        let fgPollInterval: TimeInterval   // foreground poll (seconds)
        let bgPollInterval: TimeInterval   // background poll (seconds)
        let spamCheckEveryN: Int           // check spam every N cycles
    }

    static let providers: [Provider] = [
        Provider(
            name: "Yandex",
            domains: ["yandex.ru", "ya.ru", "yandex.com"],
            imapHost: "imap.yandex.ru", imapPort: 993,
            smtpHost: "smtp.yandex.ru", smtpPort: 465,
            fgPollInterval: 5, bgPollInterval: 30, spamCheckEveryN: 6
        ),
        Provider(
            name: "Mail.ru",
            domains: ["mail.ru", "inbox.ru", "list.ru", "bk.ru"],
            imapHost: "imap.mail.ru", imapPort: 993,
            smtpHost: "smtp.mail.ru", smtpPort: 465,
            fgPollInterval: 15, bgPollInterval: 60, spamCheckEveryN: 4
        ),
        Provider(
            name: "Rambler",
            domains: ["rambler.ru", "lenta.ru", "autorambler.ru", "ro.ru"],
            imapHost: "imap.rambler.ru", imapPort: 993,
            smtpHost: "smtp.rambler.ru", smtpPort: 465,
            fgPollInterval: 10, bgPollInterval: 45, spamCheckEveryN: 5
        ),
        Provider(
            name: "Gmail",
            domains: ["gmail.com", "googlemail.com"],
            imapHost: "imap.gmail.com", imapPort: 993,
            smtpHost: "smtp.gmail.com", smtpPort: 465,
            fgPollInterval: 10, bgPollInterval: 45, spamCheckEveryN: 5
        ),
    ]

    /// Default provider for unknown domains
    static let defaultProvider = Provider(
        name: "Other",
        domains: [],
        imapHost: "", imapPort: 993,
        smtpHost: "", smtpPort: 465,
        fgPollInterval: 10, bgPollInterval: 45, spamCheckEveryN: 5
    )

    /// Spam folder names to check (multi-language)
    static let spamFolderNames = ["Spam", "Спам", "Junk", "Junk E-mail", "INBOX.Spam", "INBOX.Junk"]

    /// Find provider by email address
    static func findProvider(for email: String) -> Provider {
        let domain = email.lowercased().components(separatedBy: "@").last ?? ""
        return providers.first { $0.domains.contains(domain) } ?? defaultProvider
    }
}
