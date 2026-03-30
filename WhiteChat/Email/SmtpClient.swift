import Foundation
import MailCore

/// SMTP client for sending encrypted emails — matches Android SmtpClient
final class SmtpClient {
    private let session: MCOSMTPSession

    init(email: String, password: String) {
        let provider = EmailConstants.findProvider(for: email)
        session = MCOSMTPSession()
        session.hostname = provider.smtpHost
        session.port = UInt32(provider.smtpPort)
        session.username = email
        session.password = password
        session.connectionType = .TLS
        session.authType = .saslPlain
        session.timeout = 30
    }

    /// Send encrypted message
    func send(
        from: String,
        to: String,
        subject: String,
        body: String,
        attachmentData: Data? = nil,
        attachmentFilename: String? = nil,
        attachmentMimeType: String? = nil
    ) async throws {
        let builder = MCOMessageBuilder()
        builder.header.from = MCOAddress(displayName: nil, mailbox: from)
        builder.header.to = [MCOAddress(displayName: nil, mailbox: to)!]
        builder.header.subject = subject

        // Custom header for WhiteChat identification
        builder.header.setExtraHeaderValue(
            EmailConstants.headerValue,
            forName: EmailConstants.headerName
        )

        builder.textBody = body

        // Attachment
        if let data = attachmentData, let filename = attachmentFilename {
            let attachment = MCOAttachment()
            attachment.filename = filename
            attachment.mimeType = attachmentMimeType ?? "application/octet-stream"
            attachment.data = data
            builder.addAttachment(attachment)
        }

        let messageData = builder.data()!
        let sendOp = session.sendOperation(with: messageData)!

        return try await withCheckedThrowingContinuation { continuation in
            sendOp.start { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
