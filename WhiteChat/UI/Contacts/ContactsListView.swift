import SwiftUI
import CoreImage.CIFilterBuiltins

/// Contact list — matches Android ContactsScreen
/// Properly displays parsed name/email, not raw QR strings
struct ContactsListView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @StateObject private var contactRepo = ContactRepository.shared
    @State private var showAddContact = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(L("contacts_section_title"))) {
                    ForEach(contactRepo.contacts) { contact in
                        ContactRow(contact: contact)
                    }
                    .onDelete(perform: deleteContacts)
                }
            }
            .navigationTitle(L("contacts_title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddContact = true } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddContact) {
                NewChatView()
            }
        }
    }

    private func deleteContacts(offsets: IndexSet) {
        for index in offsets {
            let contact = contactRepo.contacts[index]
            try? contactRepo.deleteContact(email: contact.email)
        }
    }
}

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: contact.displayName, hue: contact.avatarColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(contact.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if contact.hasPublicKey {
                Image(systemName: "lock.fill").font(.caption).foregroundColor(AppTheme.green)
            } else {
                Image(systemName: "lock.open").font(.caption).foregroundColor(AppTheme.orange)
            }
        }
    }
}
