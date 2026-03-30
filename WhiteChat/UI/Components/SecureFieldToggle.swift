import SwiftUI

/// Password field with eye toggle — matches Android password visibility toggle
struct SecureFieldToggle: View {
    let label: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack {
            if isVisible {
                TextField(label, text: $text)
                    .textContentType(.password)
                    .autocapitalization(.none)
            } else {
                SecureField(label, text: $text)
                    .textContentType(.password)
            }

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.secondary)
            }
        }
    }
}
