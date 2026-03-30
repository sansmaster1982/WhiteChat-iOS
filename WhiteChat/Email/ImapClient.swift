import Foundation
import Network

/// IMAP client for receiving encrypted emails — native implementation
/// Uses provider-adaptive polling (no IDLE — Yandex breaks it)
final class ImapClient {
    private let email: String
    private let password: String
    private let provider: EmailConstants.Provider

    // Adaptive polling
    private var backoffMultiplier: Int = 1
    private var pollCycleCount: Int = 0

    init(email: String, password: String) {
        self.email = email
        self.password = password
        self.provider = EmailConstants.findProvider(for: email)
    }

    /// Current poll interval based on foreground/background + backoff
    func pollInterval(foreground: Bool) -> TimeInterval {
        let base = foreground ? provider.fgPollInterval : provider.bgPollInterval
        return base * Double(backoffMultiplier)
    }

    /// Fetch new messages from INBOX
    func fetchNewMessages() async throws -> [(sender: String, body: String, messageId: String)] {
        let session = NativeImapSession(
            host: provider.imapHost,
            port: provider.imapPort,
            username: email,
            password: password
        )

        let rawMessages = try await session.fetchUnseenMessages(folder: "INBOX")

        // Filter WhiteChat messages
        var results: [(sender: String, body: String, messageId: String)] = []
        for msg in rawMessages {
            if msg.subject.hasPrefix(EmailConstants.subjectPrefix) ||
               msg.headers.contains(where: { $0.key == EmailConstants.headerName && $0.value == EmailConstants.headerValue }) {
                results.append((sender: msg.from, body: msg.body, messageId: msg.messageId))
            }
        }

        // Success — reduce backoff
        if backoffMultiplier > 1 {
            backoffMultiplier = max(1, backoffMultiplier / 2)
        }
        pollCycleCount += 1

        return results
    }

    /// Check spam folder for misplaced messages
    func checkSpamFolder() async throws -> [(sender: String, body: String, messageId: String)] {
        var results: [(sender: String, body: String, messageId: String)] = []

        for spamName in EmailConstants.spamFolderNames {
            do {
                let session = NativeImapSession(
                    host: provider.imapHost,
                    port: provider.imapPort,
                    username: email,
                    password: password
                )
                let rawMessages = try await session.fetchUnseenMessages(folder: spamName)
                for msg in rawMessages {
                    if msg.subject.hasPrefix(EmailConstants.subjectPrefix) {
                        results.append((sender: msg.from, body: msg.body, messageId: msg.messageId))
                    }
                }
            } catch {
                // Folder might not exist — skip
                continue
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
}

// MARK: - Native IMAP Session

struct ImapMessage {
    let from: String
    let subject: String
    let body: String
    let messageId: String
    let headers: [(key: String, value: String)]
}

private class NativeImapSession {
    let host: String
    let port: Int
    let username: String
    let password: String

    init(host: String, port: Int, username: String, password: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }

    func fetchUnseenMessages(folder: String) async throws -> [ImapMessage] {
        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "imap")

            let tlsOptions = NWProtocolTLS.Options()
            let tcpOptions = NWProtocolTCP.Options()
            let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: params
            )

            var messages: [ImapMessage] = []
            var tagCounter = 1

            func nextTag() -> String {
                let tag = "A\(tagCounter)"
                tagCounter += 1
                return tag
            }

            func sendCommand(_ cmd: String, completion: @escaping (String) -> Void) {
                let data = (cmd + "\r\n").data(using: .utf8)!
                connection.send(content: data, completion: .contentProcessed { error in
                    if error != nil { return }
                    // Read response
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
                        let response = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                        completion(response)
                    }
                })
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Read greeting
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                        let tag1 = nextTag()
                        sendCommand("\(tag1) LOGIN \(self.username) \(self.password)") { response in
                            if response.contains("OK") {
                                let tag2 = nextTag()
                                sendCommand("\(tag2) SELECT \(folder)") { _ in
                                    let tag3 = nextTag()
                                    sendCommand("\(tag3) SEARCH UNSEEN") { searchResp in
                                        // Parse UIDs from "* SEARCH 1 2 3"
                                        let uids = searchResp
                                            .components(separatedBy: "\r\n")
                                            .first(where: { $0.contains("* SEARCH") })?
                                            .replacingOccurrences(of: "* SEARCH ", with: "")
                                            .split(separator: " ")
                                            .compactMap { Int($0) } ?? []

                                        if uids.isEmpty {
                                            let tagL = nextTag()
                                            sendCommand("\(tagL) LOGOUT") { _ in
                                                connection.cancel()
                                                continuation.resume(returning: messages)
                                            }
                                            return
                                        }

                                        // Fetch each message
                                        let uidList = uids.map(String.init).joined(separator: ",")
                                        let tag4 = nextTag()
                                        sendCommand("\(tag4) FETCH \(uidList) (BODY[HEADER] BODY[TEXT])") { fetchResp in
                                            // Basic parsing
                                            let msg = ImapMessage(
                                                from: self.extractHeader("From", from: fetchResp),
                                                subject: self.extractHeader("Subject", from: fetchResp),
                                                body: self.extractBody(from: fetchResp),
                                                messageId: self.extractHeader("Message-ID", from: fetchResp),
                                                headers: [(key: EmailConstants.headerName,
                                                           value: self.extractHeader(EmailConstants.headerName, from: fetchResp))]
                                            )
                                            if !msg.body.isEmpty {
                                                messages.append(msg)
                                            }

                                            let tagL = nextTag()
                                            sendCommand("\(tagL) LOGOUT") { _ in
                                                connection.cancel()
                                                continuation.resume(returning: messages)
                                            }
                                        }
                                    }
                                }
                            } else {
                                connection.cancel()
                                continuation.resume(throwing: NSError(domain: "IMAP", code: 401,
                                    userInfo: [NSLocalizedDescriptionKey: "Login failed"]))
                            }
                        }
                    }
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }

    private func extractHeader(_ name: String, from response: String) -> String {
        let pattern = "\(name): "
        guard let range = response.range(of: pattern, options: .caseInsensitive) else { return "" }
        let start = range.upperBound
        let rest = response[start...]
        if let end = rest.range(of: "\r\n") {
            return String(rest[..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractBody(from response: String) -> String {
        // Find body section between BODY[TEXT] markers
        if let range = response.range(of: "\r\n\r\n") {
            let bodyPart = String(response[range.upperBound...])
            // Remove IMAP tags at the end
            if let endRange = bodyPart.range(of: "\r\n)") {
                return String(bodyPart[..<endRange.lowerBound])
            }
            return bodyPart.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}
