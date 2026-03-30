import Foundation
import GRDB

/// Contact model — matches Android Room Contact entity
struct Contact: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var email: String
    var displayName: String
    var hasPublicKey: Bool
    var addedAt: Date
    var avatarColor: Int  // hue value 0-360

    static let databaseTableName = "contacts"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Contact {
    /// Generate consistent avatar color from email
    static func colorForEmail(_ email: String) -> Int {
        let hash = abs(email.hashValue)
        return hash % 360
    }

    /// Create new contact
    static func create(email: String, name: String = "") -> Contact {
        Contact(
            email: email.lowercased(),
            displayName: name.isEmpty ? email.components(separatedBy: "@").first ?? email : name,
            hasPublicKey: PgpKeyManager.shared.hasContactKey(email: email),
            addedAt: Date(),
            avatarColor: colorForEmail(email)
        )
    }
}
