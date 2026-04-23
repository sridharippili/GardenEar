import SwiftUI

enum Theme {
    // MARK: - Primary palette
    static let primary         = Color(hex: "#3A7D44")  // deep garden green
    static let secondary       = Color(hex: "#52B788")  // mid green
    static let accent          = Color(hex: "#95D5B2")  // light mint
    static let background      = Color(hex: "#F8FAF8")  // near-white with green tint
    static let surface         = Color(hex: "#FFFFFF")  // card backgrounds
    static let textPrimary     = Color(hex: "#1B2F1E")  // near-black green
    static let textSecondary   = Color(hex: "#4A6741")  // muted green-gray

    // MARK: - Life stage badge colors
    static let chickFill       = Color(hex: "#FFF3B0")
    static let chickText       = Color(hex: "#7A5C00")
    static let juvenileFill    = Color(hex: "#FFD199")
    static let juvenileText    = Color(hex: "#7A3500")
    static let adultFill       = Color(hex: "#B7E4C7")
    static let adultText       = Color(hex: "#1B4332")
    static let unknownFill     = Color(hex: "#E0E0E0")
    static let unknownText     = Color(hex: "#4A4A4A")

    // MARK: - Typography
    static let titleFont       = Font.system(size: 32, weight: .bold,     design: .rounded)
    static let headingFont     = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let bodyFont        = Font.system(size: 16, weight: .regular,  design: .default)
    static let captionFont     = Font.system(size: 13, weight: .regular,  design: .default)
    static let badgeFont       = Font.system(size: 12, weight: .semibold, design: .rounded)

    // MARK: - Dark mode overrides
    static let backgroundDark  = Color(hex: "#0F1A10")
    static let surfaceDark     = Color(hex: "#1A2E1C")
    static let textPrimaryDark = Color(hex: "#E8F5E9")
    static let textSecondaryDark = Color(hex: "#A5C8A8")
}

// MARK: - Hex color initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
