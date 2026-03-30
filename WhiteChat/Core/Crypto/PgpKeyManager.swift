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

    /// Generate RSA-4096 PGP key pair
    func generateKeyPair(email: String, name: String) throws {
        let key = KeyGenerator()
            .generate(for: "\(name) <\(email)>", passphrase: nil)

        // Export public key
        let publicData = try key.export(keyType: .public)
        let publicArmored = Armor.armored(publicData, as: .publicKey)
        try publicArmored.write(
            to: keyDir.appendingPathComponent("public.asc"),
            atomically: true,
            encoding: .utf8
        )

        // Export secret key
        let secretData = try key.export(keyType: .secret)
        let secretArmored = Armor.armored(secretData, as: .secretKey)
        try secretArmored.write(
            to: keyDir.appendingPathComponent("secret.asc"),
            atomically: true,
            encoding: .utf8
        )
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
