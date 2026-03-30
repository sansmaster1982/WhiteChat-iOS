import Foundation

/// Encryption constants — must match Android CryptoConstants exactly
enum CryptoConstants {
    static let pgpKeySize = 4096
    static let pbkdf2Iterations = 600_000
    static let pbkdf2KeyLength = 32  // bytes (256 bits)
    static let saltLength = 16
    static let nonceLength = 12
    static let gcmTagBits = 128
}
