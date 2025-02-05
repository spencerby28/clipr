import SwiftUI

extension Color {
    /// Initializes a `Color` from a hex string.
    /// Accepts formats with or without a hash (e.g., "#4c5760" or "4c5760").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17,
                            ((int >> 4) & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16,
                            (int >> 8) & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                            (int >> 16) & 0xFF,
                            (int >> 8) & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Custom color palette
    static let outerSpace = Color(hex: "4c5760")    // Outer space
    static let cadetGray  = Color(hex: "93a8ac")    // Cadet gray
    static let burntSienna = Color(hex: "dd6e42")    // Burnt sienna
    static let blackBean   = Color(hex: "250902")    // Black bean
    static let dimGray    = Color(hex: "66635b")     // Dim gray
} 