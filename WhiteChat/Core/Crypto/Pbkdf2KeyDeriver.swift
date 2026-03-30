import Foundation
import CommonCrypto

/// PBKDF2-HMAC-SHA512 key derivation — must match Android exactly
enum Pbkdf2KeyDeriver {
    /// Derive AES-256 key from password using PBKDF2-HMAC-SHA512
    static func deriveKey(password: String, salt: Data) -> Data? {
        let passwordBytes = Array(password.utf8) // UTF-8 bytes — cross-platform compatible
        var derivedKey = [UInt8](repeating: 0, count: CryptoConstants.pbkdf2KeyLength)

        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordBytes, passwordBytes.count,
            [UInt8](salt), salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
            UInt32(CryptoConstants.pbkdf2Iterations),
            &derivedKey, CryptoConstants.pbkdf2KeyLength
        )

        guard status == kCCSuccess else { return nil }
        return Data(derivedKey)
    }

    /// Generate random salt
    static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: CryptoConstants.saltLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Generate random IV/nonce
    static func generateNonce() -> Data {
        var bytes = [UInt8](repeating: 0, count: CryptoConstants.nonceLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
