import Foundation

enum IconMapper {
    static func materialToSFSymbol(_ materialIcon: String) -> String {
        let mapping: [String: String] = [
            "card_giftcard": "gift",
            "checklist": "checklist",
            "celebration": "party.popper",
            "cake": "birthday.cake",
            "favorite": "heart.fill",
            "star": "star.fill",
            "redeem": "giftcard",
            "shopping_bag": "bag.fill",
            "shopping_cart": "cart.fill",
            "home": "house.fill",
            "flight": "airplane",
            "child_care": "figure.and.child.holdinghands",
            "pets": "pawprint.fill",
            "devices": "laptopcomputer",
            "checkroom": "tshirt.fill",
            "auto_stories": "book.fill",
            "sports_esports": "gamecontroller.fill",
            "palette": "paintpalette.fill",
            "music_note": "music.note",
            "restaurant": "fork.knife",
            "fitness_center": "dumbbell.fill",
            "photo_camera": "camera.fill",
            "spa": "leaf.fill",
            "directions_car": "car.fill",
            "diamond": "sparkles",
        ]

        return mapping[materialIcon] ?? "list.bullet"
    }
}
