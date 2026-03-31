import SwiftUI
import CodeScanner

/// New chat — enter email or scan QR code
/// Matches Android NewChatScreen
struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var showQRScanner = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(L("new_chat_description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                TextField(L("new_chat_email_placeholder"), text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal)

                // Scan QR button
                Button {
                    showQRScanner = true
                } label: {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text(L("new_chat_scan_qr"))
                    }
                    .font(.headline)
                    .foregroundColor(AppTheme.primary)
                }

                Spacer()

                Button {
                    addContact()
                } label: {
                    Text(L("new_chat_add"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(email.contains("@") ? AppTheme.primary : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!email.contains("@"))
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle(L("new_chat_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("cancel")) { dismiss() }
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { result in
                    handleQRResult(result)
                }
            }
            .alert(L("error"), isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addContact() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@") else { return }

        if ContactRepository.shared.contactExists(email: trimmed) {
            errorMessage = L("new_chat_already_exists")
            showError = true
            return
        }

        do {
            try ContactRepository.shared.addContact(Contact.create(email: trimmed))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleQRResult(_ result: String) {
        showQRScanner = false
        // QR contains PGP public key
        if result.contains("-----BEGIN PGP PUBLIC KEY BLOCK-----") {
            if let extractedEmail = PgpCryptoEngine.shared.extractEmail(from: result) {
                email = extractedEmail
                // Save key
                try? PgpKeyManager.shared.saveContactKey(email: extractedEmail, armoredKey: result)
                addContact()
            }
        } else if result.contains("@") {
            email = result
        }
    }
}
