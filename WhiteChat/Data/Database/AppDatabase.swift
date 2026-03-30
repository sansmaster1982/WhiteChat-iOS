import Foundation
import GRDB

/// GRDB database setup — equivalent to Android Room
final class AppDatabase {
    static let shared = AppDatabase()

    let dbQueue: DatabaseQueue

    private init() {
        let dbPath = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("whitechat.sqlite")

        do {
            dbQueue = try DatabaseQueue(path: dbPath.path)
            try migrator.migrate(dbQueue)
        } catch {
            fatalError("Database init failed: \(error)")
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "contacts") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("email", .text).notNull().unique()
                t.column("displayName", .text).notNull()
                t.column("hasPublicKey", .boolean).notNull().defaults(to: false)
                t.column("addedAt", .datetime).notNull()
                t.column("avatarColor", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "messages") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("contactEmail", .text).notNull().indexed()
                t.column("body", .text).notNull()
                t.column("isOutgoing", .boolean).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("status", .text).notNull()
                t.column("attachmentPath", .text)
                t.column("attachmentType", .text)
                t.column("emailMessageId", .text).unique()
            }
        }

        return migrator
    }
}
