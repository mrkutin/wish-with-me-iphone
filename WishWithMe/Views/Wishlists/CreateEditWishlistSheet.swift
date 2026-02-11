import SwiftUI

struct CreateEditWishlistSheet: View {
    @Environment(\.dismiss) private var dismiss

    let editingWishlist: Wishlist?
    let onSave: (String, String?, String, String) -> Void

    @State private var name: String
    @State private var descriptionText: String
    @State private var selectedIcon: String
    @State private var selectedColor: String

    init(
        editingWishlist: Wishlist? = nil,
        onSave: @escaping (String, String?, String, String) -> Void
    ) {
        self.editingWishlist = editingWishlist
        self.onSave = onSave
        _name = State(initialValue: editingWishlist?.name ?? "")
        _descriptionText = State(initialValue: editingWishlist?.descriptionText ?? "")
        _selectedIcon = State(initialValue: editingWishlist?.icon ?? "card_giftcard")
        _selectedColor = State(initialValue: editingWishlist?.iconColor ?? "primary")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Wishlist name", text: $name)
                }

                Section("Description") {
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Icon") {
                    IconPickerView(
                        selectedIcon: $selectedIcon,
                        accentColor: IconColorMapper.color(for: selectedColor)
                    )
                    .accessibilityLabel("Icon picker")
                }

                Section("Color") {
                    ColorPickerView(selectedColor: $selectedColor)
                        .accessibilityLabel("Color picker")
                }
            }
            .navigationTitle(editingWishlist == nil ? "New Wishlist" : "Edit Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingWishlist == nil ? "Create" : "Save") {
                        let desc: String? = descriptionText.isEmpty ? nil : descriptionText
                        onSave(
                            name.trimmingCharacters(in: .whitespaces),
                            desc,
                            selectedIcon,
                            selectedColor
                        )
                        HapticManager.notification(.success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
