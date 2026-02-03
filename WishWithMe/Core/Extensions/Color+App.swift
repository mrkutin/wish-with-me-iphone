import SwiftUI

// MARK: - App Colors

extension Color {
    // Primary Colors
    static let appPrimary = Color(hex: "#4F46E5")
    static let appPrimaryDark = Color(hex: "#4338CA")
    static let appPrimaryLight = Color(hex: "#6366F1")

    // Background Colors
    static let appBackground = Color(.systemBackground)
    static let appSecondaryBackground = Color(.secondarySystemBackground)
    static let appTertiaryBackground = Color(.tertiarySystemBackground)

    // Status Colors
    static let appError = Color(hex: "#EF4444")
    static let appSuccess = Color(hex: "#22C55E")
    static let appWarning = Color(hex: "#F59E0B")
    static let appInfo = Color(hex: "#3B82F6")

    // Marketplace Colors
    static let ozonBlue = Color(hex: "#005BFF")
    static let wildberriesPurple = Color(hex: "#CB11AB")
    static let yandexYellow = Color(hex: "#FFCC00")
    static let aliexpressOrange = Color(hex: "#FF4747")
    static let amazonOrange = Color(hex: "#FF9900")

    // Text Colors
    static let appTextPrimary = Color(.label)
    static let appTextSecondary = Color(.secondaryLabel)
    static let appTextTertiary = Color(.tertiaryLabel)

    // Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
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
}

// MARK: - Marketplace Color Extension

extension Marketplace {
    var color: Color {
        switch self {
        case .ozon:
            return .ozonBlue
        case .wildberries:
            return .wildberriesPurple
        case .yandexMarket:
            return .yandexYellow
        case .aliexpress:
            return .aliexpressOrange
        case .amazon:
            return .amazonOrange
        }
    }
}
