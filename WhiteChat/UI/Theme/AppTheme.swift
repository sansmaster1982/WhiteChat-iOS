import SwiftUI

/// App color palette — dark-first design matching Android theme
enum AppTheme {
    // Primary colors
    static let primary = Color(hex: 0xFF6200EE)
    static let primaryVariant = Color(hex: 0xFF3700B3)
    static let secondary = Color(hex: 0xFF03DAC6)

    // Dark theme
    static let darkBackground = Color(hex: 0xFF121212)
    static let darkSurface = Color(hex: 0xFF1E1E1E)
    static let darkCard = Color(hex: 0xFF2A2A2A)
    static let darkText = Color.white
    static let darkTextSecondary = Color(white: 0.7)

    // Light theme
    static let lightBackground = Color(hex: 0xFFF5F5F5)
    static let lightSurface = Color.white
    static let lightCard = Color(hex: 0xFFF0F0F0)
    static let lightText = Color.black
    static let lightTextSecondary = Color(white: 0.4)

    // Message bubbles
    static let outgoingBubble = Color(hex: 0xFF6200EE)
    static let incomingBubbleDark = Color(hex: 0xFF2A2A2A)
    static let incomingBubbleLight = Color(hex: 0xFFE8E8E8)

    // Accent
    static let green = Color(hex: 0xFF4CAF50)
    static let red = Color(hex: 0xFFF44336)
    static let orange = Color(hex: 0xFFFF9800)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Generate color from hue (for avatar circles)
    static func fromHue(_ hue: Int) -> Color {
        Color(hue: Double(hue) / 360.0, saturation: 0.6, brightness: 0.8)
    }
}
