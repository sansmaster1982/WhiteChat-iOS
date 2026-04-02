import SwiftUI

/// Main tab navigation — matches Android BottomNavigation + global QR button
struct MainTabView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var selectedTab = 0
    @State private var showQRSheet = false

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ChatsListView()
                    .tabItem {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text(L("tab_chats"))
                    }
                    .tag(0)

                ContactsListView()
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text(L("tab_contacts"))
                    }
                    .tag(1)

                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text(L("tab_settings"))
                    }
                    .tag(2)
            }
            .accentColor(AppTheme.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showQRSheet = true
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showQRSheet) {
                QRTabsView()
            }
        }
    }
}

// MARK: - QR Tabs View (My QR + Scan QR) — matches Android

struct QRTabsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack {
                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text(L("contacts_my_qr")).tag(0)
                    Text(L("new_chat_scan_qr")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if selectedTab == 0 {
                    myQRContent
                } else {
                    scanQRContent
                }
            }
            .navigationTitle("QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("done")) { dismiss() }
                }
            }
        }
    }

    // MARK: - My QR Tab

    private var myQRContent: some View {
        VStack(spacing: 24) {
            Spacer()

            if let qrString = PgpKeyManager.shared.getQRString(
                email: settingsStore.accountEmail,
                name: settingsStore.displayName
            ) {
                if let qrImage = generateQR(from: qrString) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                }

                Text(settingsStore.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(settingsStore.accountEmail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text(L("contacts_no_key"))
                    .foregroundColor(.secondary)
            }

            Text(L("contacts_qr_description"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Scan QR Tab

    private var scanQRContent: some View {
        CodeScannerView(codeTypes: [.qr]) { result in
            switch result {
            case .success(let scanResult):
                handleScan(scanResult.string)
            case .failure:
                break
            }
        }
    }

    private func handleScan(_ result: String) {
        // Parse OPENPGP4FPR and add contact
        if result.uppercased().hasPrefix("OPENPGP4FPR:") {
            let parsed = parseOpenPGP4FPR(result)
            if let parsedEmail = parsed.email {
                if !ContactRepository.shared.contactExists(email: parsedEmail) {
                    try? ContactRepository.shared.addContact(
                        Contact.create(email: parsedEmail, name: parsed.name ?? "")
                    )
                }
            }
        } else if result.contains("-----BEGIN PGP PUBLIC KEY BLOCK-----") {
            if let extractedEmail = PgpCryptoEngine.shared.extractEmail(from: result) {
                try? PgpKeyManager.shared.saveContactKey(email: extractedEmail, armoredKey: result)
                if !ContactRepository.shared.contactExists(email: extractedEmail) {
                    try? ContactRepository.shared.addContact(Contact.create(email: extractedEmail))
                }
            }
        }
        dismiss()
    }

    private func parseOpenPGP4FPR(_ raw: String) -> (email: String?, name: String?) {
        var str = raw
        if let range = str.range(of: "OPENPGP4FPR:", options: .caseInsensitive) {
            str = String(str[range.upperBound...])
        }
        let parts = str.split(separator: "#", maxSplits: 1)
        var email: String?
        var name: String?
        if parts.count > 1 {
            let pairs = String(parts[1]).split(separator: "&")
            for pair in pairs {
                let kv = pair.split(separator: "=", maxSplits: 1)
                guard kv.count == 2 else { continue }
                let key = String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                if key == "a" { email = value }
                if key == "n" { name = value }
            }
        }
        return (email: email, name: name)
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
