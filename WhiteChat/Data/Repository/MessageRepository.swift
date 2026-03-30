import Foundation
import GRDB
import Combine

/// Message data access — equivalent to Android MessageDao + Repository
final class MessageRepository: ObservableObject {
    static let shared = MessageRepository()
    private let db = AppDatabase.shared.dbQueue

    private init() {}

    /// Get messages for a contact, ordered by timestamp
    func messages(for contactEmail: String) -> [Message] {
        (try? db.read { db in
            try Message
                .filter(Column("contactEmail") == contactEmail.lowercased())
                .order(Column("timestamp").asc)
                .fetchAll(db)
        }) ?? []
    }

    /// Get last message for each contact (for chat list)
    func lastMessages() -> [String: Message] {
        guard let messages = try? db.read({ db in
            try Message.order(Column("timestamp").desc).fetchAll(db)
        }) else { return [:] }

        var result: [String: Message] = [:]
        for msg in messages {
            if result[msg.contactEmail] == nil {
                result[msg.contactEmail] = msg
            }
        }
        return result
    }

    /// Insert message
    @discardableResult
    func insert(_ message: Message) throws -> Message {
        var msg = message
        try db.write { db in
            try msg.insert(db)
        }
        return msg
    }

    /// Update message status
    func updateStatus(id: Int64, status: MessageStatus) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE messages SET status = ? WHERE id = ?",
                arguments: [status.rawValue, id]
            )
        }
    }

    /// Check if message already exists (dedup by email Message-ID)
    func messageExists(emailMessageId: String) -> Bool {
        (try? db.read { db in
            try Message
                .filter(Column("emailMessageId") == emailMessageId)
                .fetchCount(db) > 0
        }) ?? false
    }

    /// Delete all messages for a contact
    func deleteMessages(for contactEmail: String) throws {
        try db.write { db in
            try Message
                .filter(Column("contactEmail") == contactEmail.lowercased())
                .deleteAll(db)
        }
    }

    /// Count unread messages (received messages newer than last read)
    func unreadCount(for contactEmail: String) -> Int {
        (try? db.read { db in
            try Message
                .filter(Column("contactEmail") == contactEmail.lowercased())
                .filter(Column("status") == MessageStatus.received.rawValue)
                .fetchCount(db)
        }) ?? 0
    }
}
