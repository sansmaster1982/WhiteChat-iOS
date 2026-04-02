import Foundation
import ObjectivePGP

/// Manages PGP key generation, storage, and retrieval
/// Keys stored in Documents/keys/ as .asc files — matches Android structure
final class PgpKeyManager {
    static let shared = PgpKeyManager()

    private let fileManager = FileManager.default
    private var keyDir: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("keys")
    }

    private init() {
        try? fileManager.createDirectory(at: keyDir, withIntermediateDirectories: true)
    }

    // MARK: - Key Generation

    /// Generate RSA-4096 PGP key pair using ObjectivePGP
    func generateKeyPair(email: String, name: String) throws {
        let userId = "\(name) <\(email)>"

        // ObjectivePGP KeyGenerator
        let generator = KeyGenerator()
        let key = generator.generate(for: userId, passphrase: nil)

        // Export and save public key
        do {
            let publicData = try key.export(keyType: .public)
            let publicArmored = Armor.armored(publicData, as: .publicKey)
            let publicURL = keyDir.appendingPathComponent("public.asc")
            try publicArmored.write(to: publicURL, atomically: true, encoding: .utf8)
        } catch {
            // Fallback: save raw data as base64 armored manually
            let publicData = try key.export(keyType: .public)
            let armored = "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n\(publicData.base64EncodedString(options: .lineLength76Characters))\n-----END PGP PUBLIC KEY BLOCK-----"
            let publicURL = keyDir.appendingPathComponent("public.asc")
            try armored.write(to: publicURL, atomically: true, encoding: .utf8)
        }

        // Export and save secret key
        do {
            let secretData = try key.export(keyType: .secret)
            let secretArmored = Armor.armored(secretData, as: .secretKey)
            let secretURL = keyDir.appendingPathComponent("secret.asc")
            try secretArmored.write(to: secretURL, atomically: true, encoding: .utf8)
        } catch {
            let secretData = try key.export(keyType: .secret)
            let armored = "-----BEGIN PGP PRIVATE KEY BLOCK-----\n\n\(secretData.base64EncodedString(options: .lineLength76Characters))\n-----END PGP PRIVATE KEY BLOCK-----"
            let secretURL = keyDir.appendingPathComponent("secret.asc")
            try armored.write(to: secretURL, atomically: true, encoding: .utf8)
        }

        // Verify keys were written
        guard hasKeyPair else {
            throw CryptoError.keyGenerationFailed
        }
    }

    // MARK: - Key Retrieval

    /// Get own public key (armored string)
    func getPublicKey() -> String? {
        let url = keyDir.appendingPathComponent("public.asc")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Get own secret key (armored string)
    func getSecretKey() -> String? {
        let url = keyDir.appendingPathComponent("secret.asc")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Check if key pair exists
    var hasKeyPair: Bool {
        fileManager.fileExists(atPath: keyDir.appendingPathComponent("public.asc").path)
            && fileManager.fileExists(atPath: keyDir.appendingPathComponent("secret.asc").path)
    }

    /// Get fingerprint of own public key
    func getFingerprint() -> String? {
        guard let publicKey = getPublicKey(),
              let keyData = publicKey.data(using: .utf8),
              let keys = try? ObjectivePGP.readKeys(from: keyData),
              let key = keys.first else {
            return nil
        }
        return key.fingerprint.description().replacingOccurrences(of: " ", with: "").uppercased()
    }

    /// Build OPENPGP4FPR QR string (matches Android format)
    func getQRString(email: String, name: String) -> String? {
        guard let fingerprint = getFingerprint() else { return nil }
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return "OPENPGP4FPR:\(fingerprint)#a=\(encodedEmail)&n=\(encodedName)"
    }

    // MARK: - Contact Keys

    /// Save contact's public key
    func saveContactKey(email: String, armoredKey: String) throws {
        let filename = email.lowercased()
            .replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: ".", with: "_") + ".asc"
        try armoredKey.write(
            to: keyDir.appendingPathComponent(filename),
            atomically: true,
            encoding: .utf8
        )
    }

    /// Get contact's public key
    func getContactKey(email: String) -> String? {
        let filename = email.lowercased()
            .replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: ".", with: "_") + ".asc"
        let url = keyDir.appendingPathComponent(filename)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Check if contact's key exists
    func hasContactKey(email: String) -> Bool {
        getContactKey(email: email) != nil
    }

    /// Get all .asc filenames in key directory
    func allKeyFiles() -> [(name: String, data: Data)] {
        guard let files = try? fileManager.contentsOfDirectory(at: keyDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "asc" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return (name: url.lastPathComponent, data: data)
            }
    }

    /// Delete all keys (used in account reset)
    func deleteAllKeys() {
        try? fileManager.removeItem(at: keyDir)
        try? fileManager.createDirectory(at: keyDir, withIntermediateDirectories: true)
    }

    /// Key directory URL (for backup manager)
    var keyDirectory: URL { keyDir }
}
