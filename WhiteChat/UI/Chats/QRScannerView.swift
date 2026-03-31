import SwiftUI
import CodeScanner

/// QR scanner wrapper — scans PGP public keys from QR codes
struct QRScannerView: View {
    let onResult: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            CodeScannerView(codeTypes: [.qr]) { result in
                switch result {
                case .success(let scanResult):
                    onResult(scanResult.string)
                case .failure(let error):
                    print("Scan error: \(error)")
                    dismiss()
                }
            }
            .navigationTitle(L("qr_scanner_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("cancel")) { dismiss() }
                }
            }
        }
    }
}
