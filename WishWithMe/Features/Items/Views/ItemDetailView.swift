import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dataController) private var dataController
    @Environment(\.apiClient) private var apiClient
    @Environment(\.networkMonitor) private var networkMonitor
    @Environment(\.openURL) private var openURL

    let item: WishlistItem
    @Bindable var coordinator: WishlistsNavigationCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with image
                if let imageURL = item.image, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.appSecondaryBackground)
                                .frame(height: 200)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                        case .failure:
                            Rectangle()
                                .fill(Color.appSecondaryBackground)
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Item Info
                VStack(alignment: .leading, spacing: 16) {
                    // Name and Status
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.title2.bold())

                            if let priority = item.priority {
                                PriorityBadge(priority: priority)
                            }
                        }

                        Spacer()

                        StatusBadge(bought: item.bought)
                    }

                    // Price
                    if let price = item.price {
                        HStack {
                            Text(formatPrice(price, currency: item.currency))
                                .font(.title.bold())
                                .foregroundStyle(.appPrimary)

                            if let marketplace = item.marketplace {
                                MarketplaceBadge(marketplace: marketplace)
                            }
                        }
                    }

                    Divider()

                    // Description
                    if let description = item.itemDescription, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "item.detail.description"))
                                .font(.headline)

                            Text(description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Notes
                    if let notes = item.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "item.detail.notes"))
                                .font(.headline)

                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // URL Button
                    if let urlString = item.url, let url = URL(string: urlString) {
                        Button {
                            openURL(url)
                        } label: {
                            HStack {
                                if let marketplace = item.marketplace {
                                    Image(systemName: marketplace.iconName)
                                } else {
                                    Image(systemName: "link")
                                }

                                Text(String(localized: "item.detail.openLink"))

                                Spacer()

                                Image(systemName: "arrow.up.right")
                            }
                            .padding()
                            .background(Color.appSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "item.detail.info"))
                            .font(.headline)

                        HStack {
                            Text(String(localized: "item.detail.added"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        .font(.subheadline)

                        if item.updatedAt != item.createdAt {
                            HStack {
                                Text(String(localized: "item.detail.updated"))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            }
                            .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(String(localized: "item.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        toggleBought()
                    } label: {
                        Label(
                            item.bought
                                ? String(localized: "item.markUnbought")
                                : String(localized: "item.markBought"),
                            systemImage: item.bought ? "xmark.circle" : "checkmark.circle"
                        )
                    }

                    Button {
                        coordinator.showEditItem(item)
                    } label: {
                        Label(String(localized: "button.edit"), systemImage: "pencil")
                    }

                    if let urlString = item.url, let url = URL(string: urlString) {
                        Button {
                            openURL(url)
                        } label: {
                            Label(String(localized: "item.detail.openLink"), systemImage: "link")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteItem()
                    } label: {
                        Label(String(localized: "button.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Action Button
            Button {
                toggleBought()
            } label: {
                HStack {
                    Image(systemName: item.bought ? "xmark.circle" : "checkmark.circle")
                    Text(item.bought
                         ? String(localized: "item.markUnbought")
                         : String(localized: "item.markBought"))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(item.bought ? Color.orange : Color.appSuccess)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func formatPrice(_ price: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    private func toggleBought() {
        Task {
            try? dataController?.toggleItemBought(item)

            if let wishlist = item.wishlist, networkMonitor?.isConnected ?? false {
                let request = UpdateItemRequest(
                    name: nil,
                    description: nil,
                    url: nil,
                    price: nil,
                    currency: nil,
                    image: nil,
                    bought: item.bought,
                    priority: nil,
                    notes: nil
                )
                try? await apiClient?.updateItem(
                    wishlistId: wishlist.id,
                    itemId: item.id,
                    request: request
                )
            }
        }
    }

    private func deleteItem() {
        coordinator.showAlert(
            AlertItem.confirmation(
                title: String(localized: "item.delete.title"),
                message: String(localized: "item.delete.message"),
                confirmTitle: String(localized: "button.delete"),
                onConfirm: {
                    Task {
                        try? dataController?.markItemForDeletion(item)

                        if let wishlist = item.wishlist, networkMonitor?.isConnected ?? false {
                            try? await apiClient?.deleteItem(wishlistId: wishlist.id, itemId: item.id)
                            try? dataController?.deleteItem(item)
                        }

                        coordinator.pop()
                    }
                }
            )
        )
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let bought: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: bought ? "checkmark.circle.fill" : "circle")
            Text(bought
                 ? String(localized: "item.status.bought")
                 : String(localized: "item.status.available"))
        }
        .font(.subheadline.bold())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(bought ? Color.appSuccess.opacity(0.15) : Color.appInfo.opacity(0.15))
        .foregroundStyle(bought ? .appSuccess : .appInfo)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("Item Detail") {
    NavigationStack {
        ItemDetailView(
            item: WishlistItem(
                id: "1",
                name: "Apple AirPods Pro",
                itemDescription: "Wireless earbuds with active noise cancellation",
                url: "https://ozon.ru/product/airpods",
                price: 24999,
                currency: "RUB",
                priority: .high,
                notes: "White color preferred"
            ),
            coordinator: WishlistsNavigationCoordinator()
        )
    }
    .withDependencies(DependencyContainer.preview)
}
