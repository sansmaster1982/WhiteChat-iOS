import Foundation
import Combine

/// Email sync service — polls IMAP for new messages, matches Android EmailSyncService
final class EmailSyncService: ObservableObject {
    private let imapClient: ImapClient
    private let smtpClient: SmtpClient
    private let email: String

    private var pollTask: Task<Void, Never>?
    private var isForeground = true

    @Published var isRunning = false

    init(email: String, password: String) {
        self.email = email
        self.imapClient = ImapClient(email: email, password: password)
        self.smtpClient = SmtpClient(email: email, password: password)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        pollTask = Task { await pollLoop() }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        isRunning = false
    }

    func setForeground(_ fg: Bool) {
        isForeground = fg
    }

    // MARK: - Send

    func sendMessage(to recipient: String, encryptedBody: String, attachmentData: Data? = nil, attachmentFilename: String? = nil) async throws {
        try await smtpClient.send(
            from: email,
            to: recipient,
            subject: "\(EmailConstants.subjectPrefix)-\(UUID().uuidString.prefix(8))",
            body: encryptedBody,
            attachmentData: attachmentData,
            attachmentFilename: attachmentFilename,
            attachmentMimeType: "application/pgp-encrypted"
        )
    }

    // MARK: - Poll Loop

    private func pollLoop() async {
        while !Task.isCancelled {
            do {
                // Fetch new messages from INBOX
                let newMessages = try await imapClient.fetchNewMessages()
                for msg in newMessages {
                    await processIncomingMessage(body: msg.body, sender: msg.sender, messageId: msg.messageId)
                }

                // Check spam periodically
                if imapClient.shouldCheckSpam {
                    let spamMessages = try await imapClient.checkSpamFolder()
                    for msg in spamMessages {
                        await processIncomingMessage(body: msg.body, sender: msg.sender, messageId: msg.messageId)
                    }
                }
            } catch {
                let errorMsg = error.localizedDescription.lowercased()
                if errorMsg.contains("ratelimit") || errorMsg.contains("rate limit")
                    || errorMsg.contains("too many") || errorMsg.contains("throttl") {
                    imapClient.reportRatelimit()
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
                print("Poll error: \(error)")
            }

            // Wait for next poll
            let interval = imapClient.pollInterval(foreground: isForeground)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func processIncomingMessage(body: String, sender: String, messageId: String) async {
        // Dedup
        guard !MessageRepository.shared.messageExists(emailMessageId: messageId) else { return }

        do {
            let decrypted = try PgpCryptoEngine.shared.decrypt(armoredMessage: body)

            let senderEmail = extractSender(from: decrypted) ?? sender
            let messageText = extractBody(from: decrypted)

            // Ensure contact exists
            let repo = ContactRepository.shared
            if !repo.contactExists(email: senderEmail) {
                try repo.addContact(Contact.create(email: senderEmail))
            }

            // Save message
            let message = Message(
                contactEmail: senderEmail.lowercased(),
                body: messageText,
                isOutgoing: false,
                timestamp: Date(),
                status: .received,
                emailMessageId: messageId
            )
            try MessageRepository.shared.insert(message)
        } catch {
            print("Failed to process message: \(error)")
        }
    }

    private func extractSender(from text: String) -> String? {
        if text.hasPrefix("From: ") {
            return text.components(separatedBy: "\n").first?
                .replacingOccurrences(of: "From: ", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private func extractBody(from text: String) -> String {
        if text.hasPrefix("From: ") {
            let lines = text.components(separatedBy: "\n")
            return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}
