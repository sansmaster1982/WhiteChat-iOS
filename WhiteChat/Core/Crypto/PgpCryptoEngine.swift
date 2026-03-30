import Foundation
import ObjectivePGP

/// PGP encrypt/decrypt engine — matches Android PgpCryptoEngine
final class PgpCryptoEngine {
    static let shared = PgpCryptoEngine()
    private init() {}

    /// Encrypt message for recipient using their public key
    func encrypt(message: String, recipientPublicKeyArmored: String) throws -> String {
        let recipientKeyData = try ObjectivePGP.readKeys(from: recipientPublicKeyArmored.data(using: .utf8)!)
        guard let recipientKey = recipientKeyData.first else {
            throw CryptoError.decryptionFailed
        }

        let messageData = message.data(using: .utf8)!
        let encrypted = try ObjectivePGP.encrypt(
            messageData,
            addSignature: false,
            using: [recipientKey],
            passphraseForKey: nil
        )
        return Armor.armored(encrypted, as: .message)
    }

    /// Encrypt data (attachments) for recipient
    func encryptData(_ data: Data, recipientPublicKeyArmored: String) throws -> Data {
        let recipientKeyData = try ObjectivePGP.readKeys(from: recipientPublicKeyArmored.data(using: .utf8)!)
        guard let recipientKey = recipientKeyData.first else {
            throw CryptoError.decryptionFailed
        }

        return try ObjectivePGP.encrypt(
            data,
            addSignature: false,
            using: [recipientKey],
            passphraseForKey: nil
        )
    }

    /// Decrypt message using own secret key
    func decrypt(armoredMessage: String) throws -> String {
        guard let secretKeyArmored = PgpKeyManager.shared.getSecretKey() else {
            throw CryptoError.decryptionFailed
        }

        let secretKeys = try ObjectivePGP.readKeys(from: secretKeyArmored.data(using: .utf8)!)
        let messageData = try Armor.readArmored(armoredMessage)

        let decrypted = try ObjectivePGP.decrypt(
            messageData,
            andVerifySignature: false,
            using: secretKeys,
            passphraseForKey: nil
        )
        guard let text = String(data: decrypted, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        return text
    }

    /// Decrypt data (attachments) using own secret key
    func decryptData(_ data: Data) throws -> Data {
        guard let secretKeyArmored = PgpKeyManager.shared.getSecretKey() else {
            throw CryptoError.decryptionFailed
        }

        let secretKeys = try ObjectivePGP.readKeys(from: secretKeyArmored.data(using: .utf8)!)
        return try ObjectivePGP.decrypt(
            data,
            andVerifySignature: false,
            using: secretKeys,
            passphraseForKey: nil
        )
    }

    /// Extract email from PGP public key
    func extractEmail(from armoredKey: String) -> String? {
        guard let keys = try? ObjectivePGP.readKeys(from: armoredKey.data(using: .utf8)!) else {
            return nil
        }
        // User ID format: "Name <email@example.com>"
        guard let userId = keys.first?.users.first?.userID else { return nil }
        if let start = userId.range(of: "<"), let end = userId.range(of: ">") {
            return String(userId[start.upperBound..<end.lowerBound])
        }
        return userId
    }
}
