import Foundation

/// SMTP client for sending encrypted emails — stub until MailCore2 SPM is stable
/// TODO: Replace with MailCore2 SMTP when package available
final class SmtpClient {
    private let email: String
    private let password: String
    private let provider: EmailConstants.Provider

    init(email: String, password: String) {
        self.email = email
        self.password = password
        self.provider = EmailConstants.findProvider(for: email)
    }

    /// Send encrypted message via SMTP
    func send(
        from: String,
        to: String,
        subject: String,
        body: String,
        attachmentData: Data? = nil,
        attachmentFilename: String? = nil,
        attachmentMimeType: String? = nil
    ) async throws {
        // Build MIME message
        var message = ""
        let boundary = "WC-\(UUID().uuidString)"

        message += "From: \(from)\r\n"
        message += "To: \(to)\r\n"
        message += "Subject: \(subject)\r\n"
        message += "\(EmailConstants.headerName): \(EmailConstants.headerValue)\r\n"
        message += "MIME-Version: 1.0\r\n"

        if let data = attachmentData, let filename = attachmentFilename {
            message += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n\r\n"
            message += "--\(boundary)\r\n"
            message += "Content-Type: text/plain; charset=utf-8\r\n\r\n"
            message += body + "\r\n"
            message += "--\(boundary)\r\n"
            message += "Content-Type: \(attachmentMimeType ?? "application/octet-stream")\r\n"
            message += "Content-Disposition: attachment; filename=\"\(filename)\"\r\n"
            message += "Content-Transfer-Encoding: base64\r\n\r\n"
            message += data.base64EncodedString(options: .lineLength76Characters) + "\r\n"
            message += "--\(boundary)--\r\n"
        } else {
            message += "Content-Type: text/plain; charset=utf-8\r\n\r\n"
            message += body + "\r\n"
        }

        // Connect to SMTP via raw socket (TLS)
        try await sendViaSMTP(messageData: message, from: from, to: to)
    }

    private func sendViaSMTP(messageData: String, from: String, to: String) async throws {
        let host = provider.smtpHost
        let port = provider.smtpPort

        guard !host.isEmpty else {
            throw NSError(domain: "SMTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown provider"])
        }

        // Use NWConnection for TLS SMTP
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let smtpSession = NativeSmtpSession(
                host: host, port: port,
                username: email, password: password,
                from: from, to: to,
                messageData: messageData
            )
            smtpSession.send { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Native SMTP Session using Network.framework

import Network

private class NativeSmtpSession {
    let host: String
    let port: Int
    let username: String
    let password: String
    let from: String
    let to: String
    let messageData: String

    private var connection: NWConnection?
    private var completion: ((Error?) -> Void)?
    private let queue = DispatchQueue(label: "smtp")

    init(host: String, port: Int, username: String, password: String, from: String, to: String, messageData: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.from = from
        self.to = to
        self.messageData = messageData
    }

    func send(completion: @escaping (Error?) -> Void) {
        self.completion = completion

        let tlsOptions = NWProtocolTLS.Options()
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)

        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: params
        )

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.startSmtpHandshake()
            case .failed(let error):
                self?.finish(error: error)
            default:
                break
            }
        }

        connection?.start(queue: queue)
    }

    private func startSmtpHandshake() {
        // Read greeting
        readLine { [weak self] _ in
            guard let self = self else { return }
            self.sendCommand("EHLO whitechat.ios") { _ in
                // AUTH LOGIN
                let authString = "\0\(self.username)\0\(self.password)"
                let authBase64 = Data(authString.utf8).base64EncodedString()
                self.sendCommand("AUTH PLAIN \(authBase64)") { response in
                    if response?.hasPrefix("235") == true || response?.hasPrefix("2") == true {
                        self.sendCommand("MAIL FROM:<\(self.from)>") { _ in
                            self.sendCommand("RCPT TO:<\(self.to)>") { _ in
                                self.sendCommand("DATA") { _ in
                                    self.sendRaw(self.messageData + "\r\n.\r\n") { _ in
                                        self.sendCommand("QUIT") { _ in
                                            self.finish(error: nil)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        self.finish(error: NSError(domain: "SMTP", code: 535,
                            userInfo: [NSLocalizedDescriptionKey: "Auth failed: \(response ?? "")"]))
                    }
                }
            }
        }
    }

    private func sendCommand(_ command: String, handler: @escaping (String?) -> Void) {
        let data = (command + "\r\n").data(using: .utf8)!
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.finish(error: error)
                return
            }
            self?.readLine(handler: handler)
        })
    }

    private func sendRaw(_ text: String, handler: @escaping (String?) -> Void) {
        let data = text.data(using: .utf8)!
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.finish(error: error)
                return
            }
            self?.readLine(handler: handler)
        })
    }

    private func readLine(handler: @escaping (String?) -> Void) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                handler(response)
            } else {
                handler(nil)
            }
        }
    }

    private func finish(error: Error?) {
        connection?.cancel()
        connection = nil
        completion?(error)
        completion = nil
    }
}
