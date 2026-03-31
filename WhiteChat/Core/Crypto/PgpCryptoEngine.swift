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
        guard let keyData = armoredKey.data(using: .utf8),
              let keys = try? ObjectivePGP.readKeys(from: keyData),
              let key = keys.first else {
            return nil
        }

        // Try to get User ID from the key's public key packet
        // ObjectivePGP Key has publicKey/secretKey properties
        // User ID is typically in the key's description or can be extracted from armored text
        let keyDescription = "\(key)"

        // Fallback: parse email from armored key text directly
        // User ID line looks like: "Name <email@example.com>"
        let lines = armoredKey.components(separatedBy: "\n")
        for line in lines {
            if let start = line.range(of: "<"), let end = line.range(of: ">") {
                let email = String(line[start.upperBound..<end.lowerBound])
                if email.contains("@") {
                    return email
                }
            }
        }

        // Try from key description
        if let start = keyDescription.range(of: "<"), let end = keyDescription.range(of: ">") {
            let email = String(keyDescription[start.upperBound..<end.lowerBound])
            if email.contains("@") {
                return email
            }
        }

        return nil
    }
}
