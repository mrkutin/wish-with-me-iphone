import SwiftUI

struct BookmarkRow: View {
    let bookmark: Bookmark
    let itemCount: Int
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: IconMapper.materialToSFSymbol(bookmark.wishlistIcon ?? "card_giftcard"))
                .font(.title3)
                .foregroundStyle(IconColorMapper.color(for: bookmark.wishlistIconColor))
                .frame(width: 40, height: 40)
                .background(IconColorMapper.color(for: bookmark.wishlistIconColor).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(bookmark.wishlistName ?? String(localized: "Shared Wishlist"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let ownerName = bookmark.ownerName {
                    Text("by \(ownerName)", comment: "Owner attribution for shared wishlist")
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
                Button(role: .destructive) {
                    onRemove()
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
        .accessibilityLabel("\(bookmark.wishlistName ?? String(localized: "Shared Wishlist")), \(itemCount) items")
    }
}
