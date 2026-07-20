import SwiftUI

struct IconOption: Identifiable {
    let id: String // Material icon name (stored in data model)
    let sfSymbol: String
    let label: LocalizedStringKey
}

private let iconOptions: [IconOption] = [
    IconOption(id: "card_giftcard", sfSymbol: "gift", label: "Gift"),
    IconOption(id: "checklist", sfSymbol: "checklist", label: "Checklist"),
    IconOption(id: "celebration", sfSymbol: "party.popper", label: "Celebration"),
    IconOption(id: "cake", sfSymbol: "birthday.cake", label: "Birthday"),
    IconOption(id: "favorite", sfSymbol: "heart.fill", label: "Favorite"),
    IconOption(id: "star", sfSymbol: "star.fill", label: "Star"),
    IconOption(id: "redeem", sfSymbol: "giftcard", label: "Redeem"),
    IconOption(id: "shopping_bag", sfSymbol: "bag.fill", label: "Shopping"),
    IconOption(id: "home", sfSymbol: "house.fill", label: "Home"),
    IconOption(id: "flight", sfSymbol: "airplane", label: "Travel"),
    IconOption(id: "child_care", sfSymbol: "figure.and.child.holdinghands", label: "Kids"),
    IconOption(id: "pets", sfSymbol: "pawprint.fill", label: "Pets"),
    IconOption(id: "checkroom", sfSymbol: "tshirt.fill", label: "Clothes"),
    IconOption(id: "devices", sfSymbol: "laptopcomputer", label: "Gadgets"),
    IconOption(id: "sports_esports", sfSymbol: "gamecontroller.fill", label: "Gaming"),
    IconOption(id: "palette", sfSymbol: "paintpalette.fill", label: "Art"),
    IconOption(id: "auto_stories", sfSymbol: "book.fill", label: "Books"),
    IconOption(id: "music_note", sfSymbol: "music.note", label: "Music"),
    IconOption(id: "restaurant", sfSymbol: "fork.knife", label: "Dining"),
    IconOption(id: "fitness_center", sfSymbol: "dumbbell.fill", label: "Fitness"),
    IconOption(id: "photo_camera", sfSymbol: "camera.fill", label: "Photo"),
    IconOption(id: "spa", sfSymbol: "leaf.fill", label: "Nature"),
    IconOption(id: "directions_car", sfSymbol: "car.fill", label: "Auto"),
    IconOption(id: "diamond", sfSymbol: "sparkles", label: "Beauty"),
]

struct IconPickerView: View {
    @Binding var selectedIcon: String
    var accentColor: Color = .brandPrimary

    private let columns = [
        GridItem(.adaptive(minimum: 64), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(iconOptions) { option in
                iconButton(for: option)
            }
        }
    }

    @ViewBuilder
    private func iconButton(for option: IconOption) -> some View {
        let isSelected = selectedIcon == option.id

        Button {
            selectedIcon = option.id
        } label: {
            VStack(spacing: 4) {
                Image(systemName: option.sfSymbol)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected
                            ? accentColor.opacity(0.15)
                            : Color(.systemGray6)
                    )
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? accentColor : .clear,
                                lineWidth: 2
                            )
                    )

                Text(option.label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
