import Foundation
import MailCore

/// IMAP client for receiving encrypted emails — matches Android ImapClient
/// Uses provider-adaptive polling (no IDLE — Yandex breaks it)
final class ImapClient {
    private let session: MCOIMAPSession
    private let email: String
    private let provider: EmailConstants.Provider

    // Adaptive polling
    private var backoffMultiplier: Int = 1
    private var pollCycleCount: Int = 0

    init(email: String, password: String) {
        self.email = email
        self.provider = EmailConstants.findProvider(for: email)

        session = MCOIMAPSession()
        session.hostname = provider.imapHost
        session.port = UInt32(provider.imapPort)
        session.username = email
        session.password = password
        session.connectionType = .TLS
        session.authType = .saslPlain
        session.timeout = 30
    }

    /// Current poll interval based on foreground/background + backoff
    func pollInterval(foreground: Bool) -> TimeInterval {
        let base = foreground ? provider.fgPollInterval : provider.bgPollInterval
        return base * Double(backoffMultiplier)
    }

    /// Fetch new messages from INBOX
    func fetchNewMessages(sinceUID: UInt32 = 1) async throws -> [(uid: UInt32, header: MCOIMAPMessage, body: String, attachments: [(filename: String, data: Data)])] {
        let folder = "INBOX"

        // Fetch message headers
        let messages = try await fetchMessages(folder: folder, sinceUID: sinceUID)

        var results: [(uid: UInt32, header: MCOIMAPMessage, body: String, attachments: [(filename: String, data: Data)])] = []

        for msg in messages {
            // Check for WhiteChat header
            guard let headerValue = msg.header.extraHeaderValue(forName: EmailConstants.headerName),
                  headerValue == EmailConstants.headerValue else {
                continue
            }

            // Check subject prefix
            guard let subject = msg.header.subject,
                  subject.hasPrefix(EmailConstants.subjectPrefix) else {
                continue
            }

            // Fetch body
            let body = try await fetchBody(folder: folder, uid: msg.uid)
            let attachments = try await fetchAttachments(folder: folder, message: msg)
            results.append((uid: msg.uid, header: msg, body: body, attachments: attachments))
        }

        // Success — reduce backoff
        if backoffMultiplier > 1 {
            backoffMultiplier = max(1, backoffMultiplier / 2)
        }
        pollCycleCount += 1

        return results
    }

    /// Check spam folder for misplaced messages
    func checkSpamFolder() async throws -> [(uid: UInt32, body: String, attachments: [(filename: String, data: Data)])] {
        var results: [(uid: UInt32, body: String, attachments: [(filename: String, data: Data)])] = []

        for spamName in EmailConstants.spamFolderNames {
            let messages = try await fetchMessages(folder: spamName, sinceUID: 1)
            for msg in messages {
                guard let headerValue = msg.header.extraHeaderValue(forName: EmailConstants.headerName),
                      headerValue == EmailConstants.headerValue else {
                    continue
                }
                let body = try await fetchBody(folder: spamName, uid: msg.uid)
                let attachments = try await fetchAttachments(folder: spamName, message: msg)
                results.append((uid: msg.uid, body: body, attachments: attachments))

                // Move to INBOX
                try await moveMessage(fromFolder: spamName, uid: msg.uid, toFolder: "INBOX")
            }
        }

        return results
    }

    /// Should check spam this cycle?
    var shouldCheckSpam: Bool {
        pollCycleCount % provider.spamCheckEveryN == 0
    }

    /// Report ratelimit — increases backoff
    func reportRatelimit() {
        backoffMultiplier = min(8, backoffMultiplier * 2)
    }

    // MARK: - Private helpers

    private func fetchMessages(folder: String, sinceUID: UInt32) async throws -> [MCOIMAPMessage] {
        let range = MCORange(location: UInt64(sinceUID), length: UINT64_MAX)
        let indexSet = MCOIndexSet(range: range)
        let fetchOp = session.fetchMessagesOperation(
            withFolder: folder,
            requestKind: [.headers, .structure, .extraHeaders],
            uids: indexSet
        )!

        // Request custom header
        fetchOp.extraHeaders = [EmailConstants.headerName]

        return try await withCheckedThrowingContinuation { continuation in
            fetchOp.start { error, messages, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (messages as? [MCOIMAPMessage]) ?? [])
                }
            }
        }
    }

    private func fetchBody(folder: String, uid: UInt32) async throws -> String {
        let fetchOp = session.fetchMessageOperation(withFolder: folder, uid: uid)!
        return try await withCheckedThrowingContinuation { continuation in
            fetchOp.start { error, data in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    let parser = MCOMessageParser(data: data)
                    let body = parser?.plainTextBodyRendering() ?? ""
                    continuation.resume(returning: body)
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    private func fetchAttachments(folder: String, message: MCOIMAPMessage) async throws -> [(filename: String, data: Data)] {
        guard let parts = message.attachments() as? [MCOIMAPPart] else { return [] }
        var results: [(filename: String, data: Data)] = []

        for part in parts {
            guard let filename = part.filename, !filename.isEmpty else { continue }
            let fetchOp = session.fetchMessageAttachmentOperation(
                withFolder: folder,
                uid: message.uid,
                partID: part.partID,
                encoding: part.encoding
            )!

            let data: Data = try await withCheckedThrowingContinuation { continuation in
                fetchOp.start { error, data in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data ?? Data())
                    }
                }
            }
            results.append((filename: filename, data: data))
        }

        return results
    }

    private func moveMessage(fromFolder: String, uid: UInt32, toFolder: String) async throws {
        let indexSet = MCOIndexSet(index: UInt64(uid))
        let moveOp = session.moveMessagesOperation(withFolder: fromFolder, uids: indexSet, destFolder: toFolder)!
        return try await withCheckedThrowingContinuation { continuation in
            moveOp.start { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
