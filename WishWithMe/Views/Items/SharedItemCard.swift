import SwiftUI

struct SharedItemCard: View {
    let item: Item
    let myMark: Mark?
    let totalMarked: Int
    let canMark: Bool
    let canMarkItems: Bool
    let onMark: () -> Void
    let onUnmark: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            itemImage
            VStack(alignment: .leading, spacing: 4) {
                itemContent
                markSection
            }
        }
        .padding(12)
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

        if canMarkItems {
            if myMark != nil {
                parts.append(String(localized: "Marked by you"))
            } else if !canMark {
                parts.append(String(localized: "Already taken"))
            }
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
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Text(item.title)
                .font(.body)
                .fontWeight(.semibold)
                .lineLimit(2)

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

            if let sourceUrl = item.sourceUrl, !sourceUrl.isEmpty {
                Button {
                    if let url = URL(string: sourceUrl) {
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
        }
    }

    // MARK: - Mark Section

    @ViewBuilder
    private var markSection: some View {
        if canMarkItems {
            Divider()
                .padding(.vertical, 2)

            if let mark = myMark {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .imageScale(.small)
                        Text("Marked by you")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Button {
                        HapticManager.impact(.light)
                        onUnmark()
                    } label: {
                        Text("Unmark")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                    .accessibilityLabel("Unmark item")
                }
            } else if !canMark {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                    Text("Already taken")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    if totalMarked > 0 {
                        Text("\(totalMarked)/\(item.quantity) marked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        HapticManager.notification(.success)
                        onMark()
                    } label: {
                        Label("I'll get this", systemImage: "gift")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
                    .accessibilityLabel("Mark item as I'll get this")
                }
            }
        }
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
