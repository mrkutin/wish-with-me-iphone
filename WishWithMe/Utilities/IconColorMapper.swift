import SwiftUI

enum IconColorMapper {
    static func color(for name: String?) -> Color {
        switch name {
        case "red":         return .red
        case "pink":        return .pink
        case "purple":      return .purple
        case "deep-purple": return .indigo
        case "indigo":      return Color(hex: "3F51B5")
        case "blue":        return .blue
        case "cyan":        return .cyan
        case "teal":        return .teal
        case "green":       return .green
        case "orange":      return .orange
        case "brown":       return .brown
        default:            return Color.brandPrimary
        }
    }

    static let allColors: [(name: String, color: Color)] = [
        ("primary",     Color.brandPrimary),
        ("red",         .red),
        ("pink",        .pink),
        ("purple",      .purple),
        ("deep-purple", .indigo),
        ("blue",        .blue),
        ("cyan",        .cyan),
        ("teal",        .teal),
        ("green",       .green),
        ("orange",      .orange),
        ("brown",       .brown),
    ]
}
