import Foundation

/// .wcb key backup file manager — must match Android KeyBackupManager exactly
/// Format: "WCB1" (4B) + salt (16B) + IV (12B) + AES-256-GCM(PBKDF2-derived key, archive)
/// Archive: [nameLen:2][name][dataLen:4][data] repeated
final class KeyBackupManager {

    private let keyManager = PgpKeyManager.shared

    // MARK: - Export

    /// Export all keys to encrypted .wcb format
    func exportKeys(password: String) throws -> Data {
        let keyFiles = keyManager.allKeyFiles()
        guard !keyFiles.isEmpty else {
            throw CryptoError.invalidFormat
        }

        // Pack archive: [nameLen:2][name:UTF8][dataLen:4][data] for each file
        var archive = Data()
        for file in keyFiles {
            let nameBytes = file.name.data(using: .utf8)!
            // 2 bytes name length (big-endian)
            archive.append(UInt8((nameBytes.count >> 8) & 0xFF))
            archive.append(UInt8(nameBytes.count & 0xFF))
            archive.append(nameBytes)
            // 4 bytes data length (big-endian)
            let dataLen = file.data.count
            archive.append(UInt8((dataLen >> 24) & 0xFF))
            archive.append(UInt8((dataLen >> 16) & 0xFF))
            archive.append(UInt8((dataLen >> 8) & 0xFF))
            archive.append(UInt8(dataLen & 0xFF))
            archive.append(file.data)
        }

        // Encrypt
        let salt = Pbkdf2KeyDeriver.generateSalt()
        let nonce = Pbkdf2KeyDeriver.generateNonce()
        guard let key = Pbkdf2KeyDeriver.deriveKey(password: password, salt: salt) else {
            throw CryptoError.keyGenerationFailed
        }
        let encrypted = try AesGcmCipher.encrypt(plaintext: archive, key: key, nonce: nonce)

        // WCB1 + salt + nonce + encrypted
        var result = Data()
        result.append("WCB1".data(using: .ascii)!)
        result.append(salt)
        result.append(nonce)
        result.append(encrypted)
        return result
    }

    // MARK: - Import

    /// Import keys from encrypted .wcb data
    func importKeys(data: Data, password: String) throws -> Int {
        // Verify magic
        guard data.count > 32,
              String(data: data.prefix(4), encoding: .ascii) == "WCB1" else {
            throw CryptoError.invalidFormat
        }

        let salt = data.subdata(in: 4..<20)
        let nonce = data.subdata(in: 20..<32)
        let encrypted = data.subdata(in: 32..<data.count)

        guard let key = Pbkdf2KeyDeriver.deriveKey(password: password, salt: salt) else {
            throw CryptoError.keyGenerationFailed
        }

        let archive: Data
        do {
            archive = try AesGcmCipher.decrypt(ciphertext: encrypted, key: key, nonce: nonce)
        } catch {
            throw CryptoError.wrongPassword
        }

        // Unpack archive
        var offset = 0
        var count = 0
        let keyDir = keyManager.keyDirectory

        while offset < archive.count {
            // 2 bytes name length
            guard offset + 2 <= archive.count else { break }
            let nameLen = Int(archive[offset]) << 8 | Int(archive[offset + 1])
            offset += 2

            // name
            guard offset + nameLen <= archive.count else { break }
            let nameData = archive.subdata(in: offset..<offset + nameLen)
            guard let name = String(data: nameData, encoding: .utf8) else { break }
            offset += nameLen

            // 4 bytes data length
            guard offset + 4 <= archive.count else { break }
            let dataLen = Int(archive[offset]) << 24 | Int(archive[offset + 1]) << 16
                | Int(archive[offset + 2]) << 8 | Int(archive[offset + 3])
            offset += 4

            // data
            guard offset + dataLen <= archive.count else { break }
            let fileData = archive.subdata(in: offset..<offset + dataLen)
            offset += dataLen

            // Save file
            try fileData.write(to: keyDir.appendingPathComponent(name))
            count += 1
        }

        return count
    }
}
