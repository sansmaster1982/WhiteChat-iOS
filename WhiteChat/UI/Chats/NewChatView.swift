import SwiftUI
import CodeScanner

/// New chat — enter email or scan QR code
/// Matches Android NewChatScreen + OPENPGP4FPR QR parsing
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
                    addContact(name: "")
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

    private func addContact(name: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@") else { return }

        if ContactRepository.shared.contactExists(email: trimmed) {
            errorMessage = L("new_chat_already_exists")
            showError = true
            return
        }

        do {
            try ContactRepository.shared.addContact(Contact.create(email: trimmed, name: name))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleQRResult(_ result: String) {
        showQRScanner = false

        // 1. OPENPGP4FPR format: OPENPGP4FPR:fingerprint#a=email&n=name
        if result.uppercased().hasPrefix("OPENPGP4FPR:") {
            let parsed = parseOpenPGP4FPR(result)
            if let parsedEmail = parsed.email {
                email = parsedEmail
                addContact(name: parsed.name ?? "")
            } else {
                // No email in QR — let user type it
                errorMessage = L("new_chat_qr_no_email")
                showError = true
            }
            return
        }

        // 2. PGP public key block
        if result.contains("-----BEGIN PGP PUBLIC KEY BLOCK-----") {
            if let extractedEmail = PgpCryptoEngine.shared.extractEmail(from: result) {
                email = extractedEmail
                try? PgpKeyManager.shared.saveContactKey(email: extractedEmail, armoredKey: result)
                addContact(name: "")
            }
            return
        }

        // 3. Plain email
        if result.contains("@") {
            email = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Parse OPENPGP4FPR:fingerprint#a=email&n=name format
    /// Matches Android ContactsViewModel.importContactFromFpr()
    private func parseOpenPGP4FPR(_ raw: String) -> (fingerprint: String, email: String?, name: String?) {
        // Remove "OPENPGP4FPR:" prefix (case insensitive)
        var str = raw
        if let range = str.range(of: "OPENPGP4FPR:", options: .caseInsensitive) {
            str = String(str[range.upperBound...])
        }

        // Split fingerprint and params by "#"
        let parts = str.split(separator: "#", maxSplits: 1)
        let fingerprint = String(parts.first ?? "")

        var extractedEmail: String?
        var extractedName: String?

        if parts.count > 1 {
            let params = String(parts[1])
            // Parse URL-encoded params: a=email&n=name
            let pairs = params.split(separator: "&")
            for pair in pairs {
                let kv = pair.split(separator: "=", maxSplits: 1)
                guard kv.count == 2 else { continue }
                let key = String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])

                switch key {
                case "a": extractedEmail = value
                case "n": extractedName = value
                default: break
                }
            }
        }

        return (fingerprint: fingerprint, email: extractedEmail, name: extractedName)
    }
}
