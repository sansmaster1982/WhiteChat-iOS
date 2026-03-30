import SwiftUI

/// Circular avatar with initials — matches Android ContactAvatar
struct AvatarView: View {
    let name: String
    let hue: Int
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.fromHue(hue))
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var initials: String {
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
