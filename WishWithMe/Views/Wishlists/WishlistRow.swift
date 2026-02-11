import SwiftUI

struct WishlistRow: View {
    let wishlist: Wishlist
    let itemCount: Int
    let onShare: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: IconMapper.materialToSFSymbol(wishlist.icon))
                .font(.title3)
                .foregroundStyle(IconColorMapper.color(for: wishlist.iconColor))
                .frame(width: 40, height: 40)
                .background(IconColorMapper.color(for: wishlist.iconColor).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(wishlist.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let description = wishlist.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(itemCount)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())

            Menu {
                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wishlist.name), \(itemCount) items")
    }
}
