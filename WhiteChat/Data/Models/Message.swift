import Foundation
import GRDB

/// Message model — matches Android Room Message entity
struct Message: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var contactEmail: String
    var body: String          // decrypted text
    var isOutgoing: Bool
    var timestamp: Date
    var status: MessageStatus
    var attachmentPath: String?
    var attachmentType: AttachmentType?
    var emailMessageId: String?  // IMAP Message-ID for dedup

    static let databaseTableName = "messages"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

enum MessageStatus: String, Codable, DatabaseValueConvertible {
    case sending
    case sent
    case delivered  // confirmed on server
    case failed
    case received
}

enum AttachmentType: String, Codable, DatabaseValueConvertible {
    case image
    case voice
    case document
    case video
}
