import SwiftUI
import CoreImage.CIFilterBuiltins

/// Contact list with QR code sharing — matches Android ContactsScreen
struct ContactsListView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @StateObject private var contactRepo = ContactRepository.shared
    @State private var showMyQR = false
    @State private var showAddContact = false

    var body: some View {
        NavigationStack {
            List {
                // My QR section
                Section {
                    Button {
                        showMyQR = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode")
                                .font(.title2)
                                .foregroundColor(AppTheme.primary)
                            VStack(alignment: .leading) {
                                Text(L("contacts_my_qr"))
                                    .font(.headline)
                                Text(L("contacts_my_qr_hint"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Contacts
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
                    Button {
                        showAddContact = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showMyQR) {
                MyQRCodeView()
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

// MARK: - Contact Row

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: contact.displayName, hue: contact.avatarColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.headline)
                Text(contact.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if contact.hasPublicKey {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(AppTheme.green)
            } else {
                Image(systemName: "lock.open")
                    .font(.caption)
                    .foregroundColor(AppTheme.orange)
            }
        }
    }
}

// MARK: - My QR Code View

struct MyQRCodeView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let publicKey = PgpKeyManager.shared.getPublicKey(),
                   let qrImage = generateQR(from: publicKey) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                } else {
                    Text(L("contacts_no_key"))
                        .foregroundColor(.secondary)
                }

                Text(L("contacts_qr_description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle(L("contacts_my_qr"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("done")) { dismiss() }
                }
            }
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
