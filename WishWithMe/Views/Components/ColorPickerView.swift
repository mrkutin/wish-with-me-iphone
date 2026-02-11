import SwiftUI

struct ColorPickerView: View {
    @Binding var selectedColor: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(IconColorMapper.allColors, id: \.name) { item in
                    colorSwatch(name: item.name, color: item.color)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func colorSwatch(name: String, color: Color) -> some View {
        let isSelected = selectedColor == name

        Button {
            selectedColor = name
        } label: {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(isSelected ? color : .clear, lineWidth: 2)
                        .padding(-3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
