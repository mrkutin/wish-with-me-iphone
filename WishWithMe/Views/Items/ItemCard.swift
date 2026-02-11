import SwiftUI

struct ItemCard: View {
    let item: Item
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            itemImage
            itemContent
        }
        .padding(12)
        .frame(minHeight: 104)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = [item.title]

        if let price = item.price {
            let formattedPrice = formatPrice(price, currency: item.currency)
            parts.append(formattedPrice)
        }

        switch item.status {
        case "pending", "in_progress":
            parts.append(String(localized: "Resolving..."))
        case "error":
            parts.append(String(localized: "Resolution failed"))
        default:
            break
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Image

    @ViewBuilder
    private var itemImage: some View {
        Group {
            if let base64 = item.imageBase64,
               let data = Data(base64Encoded: cleanBase64(base64)),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color(.systemGray6)
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Content

    private var itemContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Spacer()

                Menu {
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
                .accessibilityLabel("Item options")
            }

            if let description = item.descriptionText, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if let price = item.price {
                    Text(formatPrice(price, currency: item.currency))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandPrimary)
                }

                if item.quantity > 1 {
                    Label("\(item.quantity)", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            statusBadge

            if let sourceUrl = item.sourceUrl, !sourceUrl.isEmpty {
                sourceLink(sourceUrl)
            }
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case "pending", "in_progress":
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Resolving...")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

        case "error":
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .imageScale(.small)
                Text("Resolution failed")
                    .font(.caption)
            }
            .foregroundStyle(.red)

        case "resolved":
            EmptyView()

        default:
            EmptyView()
        }
    }

    // MARK: - Source Link

    private func sourceLink(_ urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right.square")
                    .imageScale(.small)
                Text("View source")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatPrice(_ price: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    private func cleanBase64(_ base64: String) -> String {
        if let range = base64.range(of: ";base64,") {
            return String(base64[range.upperBound...])
        }
        return base64
    }
}
