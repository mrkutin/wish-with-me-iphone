import SwiftUI

struct WishlistDetailView: View {
    @Environment(\.dataController) private var dataController
    @Environment(\.apiClient) private var apiClient
    @Environment(\.networkMonitor) private var networkMonitor

    let wishlist: Wishlist
    @Bindable var coordinator: WishlistsNavigationCoordinator

    @State private var isLoading = false
    @State private var showBoughtItems = true

    var sortedItems: [WishlistItem] {
        wishlist.items
            .filter { !$0.pendingDeletion }
            .filter { showBoughtItems || !$0.bought }
            .sorted { item1, item2 in
                // Sort by bought status first, then by priority, then by date
                if item1.bought != item2.bought {
                    return !item1.bought
                }
                let priority1 = item1.priority?.sortOrder ?? 3
                let priority2 = item2.priority?.sortOrder ?? 3
                if priority1 != priority2 {
                    return priority1 < priority2
                }
                return item1.createdAt > item2.createdAt
            }
    }

    var boughtCount: Int {
        wishlist.items.filter { $0.bought && !$0.pendingDeletion }.count
    }

    var totalCount: Int {
        wishlist.items.filter { !$0.pendingDeletion }.count
    }

    var body: some View {
        Group {
            if wishlist.items.isEmpty {
                EmptyItemsView {
                    coordinator.showAddItem(to: wishlist)
                }
            } else {
                itemsList
            }
        }
        .navigationTitle(wishlist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        coordinator.showAddItem(to: wishlist)
                    } label: {
                        Label(String(localized: "item.add"), systemImage: "plus")
                    }

                    Button {
                        coordinator.showEditWishlist(wishlist)
                    } label: {
                        Label(String(localized: "wishlist.edit"), systemImage: "pencil")
                    }

                    Button {
                        coordinator.showShareWishlist(wishlist)
                    } label: {
                        Label(String(localized: "button.share"), systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Toggle(isOn: $showBoughtItems) {
                        Label(String(localized: "items.showBought"), systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            await refreshWishlist()
        }
    }

    private var itemsList: some View {
        List {
            // Progress Section
            Section {
                HStack {
                    Text(String(localized: "items.progress"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(boughtCount)/\(totalCount)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.appPrimary)
                }

                ProgressView(value: Double(boughtCount), total: Double(max(totalCount, 1)))
                    .tint(.appPrimary)
            }

            // Items Section
            Section {
                ForEach(sortedItems) { item in
                    Button {
                        coordinator.navigateToItemDetail(item)
                    } label: {
                        ItemRowView(item: item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleItemBought(item)
                        } label: {
                            Label(
                                item.bought
                                    ? String(localized: "item.markUnbought")
                                    : String(localized: "item.markBought"),
                                systemImage: item.bought ? "xmark.circle" : "checkmark.circle"
                            )
                        }
                        .tint(item.bought ? .orange : .appSuccess)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label(String(localized: "button.delete"), systemImage: "trash")
                        }

                        Button {
                            coordinator.showEditItem(item)
                        } label: {
                            Label(String(localized: "button.edit"), systemImage: "pencil")
                        }
                        .tint(.appPrimary)
                    }
                }
            } header: {
                Text(String(localized: "items.section.title"))
            }
        }
        .listStyle(.insetGrouped)
    }

    private func refreshWishlist() async {
        guard let apiClient = apiClient else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let dto = try await apiClient.getWishlist(id: wishlist.id)
            try dataController?.saveWishlist(dto)
        } catch {
            // Silently fail for refresh - user still sees cached data
        }
    }

    private func toggleItemBought(_ item: WishlistItem) {
        Task {
            try? dataController?.toggleItemBought(item)

            if networkMonitor?.isConnected ?? false {
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

    private func deleteItem(_ item: WishlistItem) {
        Task {
            try? dataController?.markItemForDeletion(item)

            if networkMonitor?.isConnected ?? false {
                try? await apiClient?.deleteItem(wishlistId: wishlist.id, itemId: item.id)
                try? dataController?.deleteItem(item)
            }
        }
    }
}

// MARK: - Item Row View

struct ItemRowView: View {
    let item: WishlistItem

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Image(systemName: item.bought ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(item.bought ? .appSuccess : .secondary)

            // Item Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.body)
                        .strikethrough(item.bought)
                        .foregroundStyle(item.bought ? .secondary : .primary)

                    if let priority = item.priority {
                        PriorityBadge(priority: priority)
                    }
                }

                HStack(spacing: 8) {
                    if let price = item.price {
                        Text(formatPrice(price, currency: item.currency))
                            .font(.subheadline.bold())
                            .foregroundStyle(.appPrimary)
                    }

                    if let marketplace = item.marketplace {
                        MarketplaceBadge(marketplace: marketplace)
                    }
                }
            }

            Spacer()

            // Sync indicator
            if item.needsSync {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func formatPrice(_ price: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Text(priority.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.2))
            .foregroundStyle(priorityColor)
            .clipShape(Capsule())
    }

    private var priorityColor: Color {
        switch priority {
        case .high: return .appError
        case .medium: return .appWarning
        case .low: return .appInfo
        }
    }
}

// MARK: - Marketplace Badge

struct MarketplaceBadge: View {
    let marketplace: Marketplace

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: marketplace.iconName)
                .font(.caption2)

            Text(marketplace.displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(marketplace.color.opacity(0.15))
        .foregroundStyle(marketplace.color)
        .clipShape(Capsule())
    }
}

// MARK: - Empty Items View

struct EmptyItemsView: View {
    let onAdd: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                String(localized: "items.empty.title"),
                systemImage: "gift"
            )
        } description: {
            Text(String(localized: "items.empty.description"))
        } actions: {
            Button {
                onAdd()
            } label: {
                Text(String(localized: "item.add"))
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Preview

#Preview("Wishlist Detail") {
    NavigationStack {
        WishlistDetailView(
            wishlist: Wishlist(
                id: "1",
                userId: "user1",
                userName: "John",
                name: "Birthday Wishlist",
                wishlistDescription: "My birthday gift ideas",
                dueDate: Date().addingTimeInterval(86400 * 30),
                sharedToken: "token123"
            ),
            coordinator: WishlistsNavigationCoordinator()
        )
    }
    .withDependencies(DependencyContainer.preview)
}
