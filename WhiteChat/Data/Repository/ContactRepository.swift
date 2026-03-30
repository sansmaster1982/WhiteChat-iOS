import Foundation
import GRDB
import Combine

/// Contact data access — equivalent to Android ContactDao + Repository
final class ContactRepository: ObservableObject {
    static let shared = ContactRepository()
    private let db = AppDatabase.shared.dbQueue

    @Published var contacts: [Contact] = []

    private init() {
        loadContacts()
    }

    func loadContacts() {
        do {
            contacts = try db.read { db in
                try Contact.order(Column("displayName").asc).fetchAll(db)
            }
        } catch {
            print("Error loading contacts: \(error)")
        }
    }

    func addContact(_ contact: Contact) throws {
        var c = contact
        try db.write { db in
            try c.insert(db)
        }
        loadContacts()
    }

    func updateContact(_ contact: Contact) throws {
        try db.write { db in
            try contact.update(db)
        }
        loadContacts()
    }

    func deleteContact(email: String) throws {
        try db.write { db in
            try Contact.filter(Column("email") == email.lowercased()).deleteAll(db)
        }
        loadContacts()
    }

    func findContact(email: String) -> Contact? {
        try? db.read { db in
            try Contact.filter(Column("email") == email.lowercased()).fetchOne(db)
        }
    }

    func contactExists(email: String) -> Bool {
        findContact(email: email) != nil
    }
}
