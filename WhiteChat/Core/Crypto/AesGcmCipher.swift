import Foundation
import CryptoKit

/// AES-256-GCM encrypt/decrypt — matches Android AES/GCM/NoPadding
enum AesGcmCipher {
    /// Encrypt data with AES-256-GCM
    static func encrypt(plaintext: Data, key: Data, nonce: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let aesNonce = try AES.GCM.Nonce(data: nonce)
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey, nonce: aesNonce)
        // ciphertext + tag (same as Android GCM output)
        return sealedBox.ciphertext + sealedBox.tag
    }

    /// Decrypt data with AES-256-GCM
    static func decrypt(ciphertext: Data, key: Data, nonce: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let aesNonce = try AES.GCM.Nonce(data: nonce)

        let tagLength = CryptoConstants.gcmTagBits / 8  // 16 bytes
        guard ciphertext.count > tagLength else {
            throw CryptoError.decryptionFailed
        }

        let encryptedData = ciphertext.prefix(ciphertext.count - tagLength)
        let tag = ciphertext.suffix(tagLength)

        let sealedBox = try AES.GCM.SealedBox(nonce: aesNonce, ciphertext: encryptedData, tag: tag)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }
}

enum CryptoError: Error, LocalizedError {
    case decryptionFailed
    case wrongPassword
    case invalidFormat
    case keyGenerationFailed

    var errorDescription: String? {
        switch self {
        case .decryptionFailed: return "Decryption failed"
        case .wrongPassword: return "Wrong password"
        case .invalidFormat: return "Invalid file format"
        case .keyGenerationFailed: return "Key generation failed"
        }
    }
}
