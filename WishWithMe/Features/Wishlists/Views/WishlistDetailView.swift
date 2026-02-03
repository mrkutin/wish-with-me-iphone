import SwiftUI

struct WishlistDetailView: View {
    @Environment(\.apiClient) private var apiClient
    @Environment(\.dataController) private var dataController
    @Environment(\.networkMonitor) private var networkMonitor

    let wishlist: Wishlist
    @Bindable var coordinator: WishlistsNavigationCoordinator

    @State private var viewModel: WishlistDetailViewModel

    init(wishlist: Wishlist, coordinator: WishlistsNavigationCoordinator) {
        self.wishlist = wishlist
        self.coordinator = coordinator
        _viewModel = State(initialValue: WishlistDetailViewModel(wishlist: wishlist))
    }

    var body: some View {
        Group {
            if viewModel.isEmpty {
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
                toolbarMenu
            }
        }
        .task {
            setupDependencies()
        }
        .refreshable {
            await viewModel.refreshWishlist()
        }
        .overlay(alignment: .top) {
            if viewModel.isOffline {
                offlineBanner
            }
        }
    }

    // MARK: - Toolbar Menu

    private var toolbarMenu: some View {
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

            // Sort options
            Menu {
                ForEach(ItemSortOption.allCases, id: \.self) { option in
                    Button {
                        if viewModel.sortOption == option {
                            viewModel.sortAscending.toggle()
                        } else {
                            viewModel.sortOption = option
                            viewModel.sortAscending = true
                        }
                    } label: {
                        HStack {
                            Text(option.displayName)
                            if viewModel.sortOption == option {
                                Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                Label(String(localized: "items.sort"), systemImage: "arrow.up.arrow.down")
            }

            Toggle(isOn: $viewModel.showBoughtItems) {
                Label(String(localized: "items.showBought"), systemImage: "checkmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        List {
            // Progress Section
            progressSection

            // Price Summary Section
            if viewModel.totalPrice > 0 || viewModel.totalBoughtPrice > 0 {
                priceSummarySection
            }

            // Items Section
            itemsSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        Section {
            HStack {
                Text(String(localized: "items.progress"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.boughtCount)/\(viewModel.totalCount)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appPrimary)
            }

            ProgressView(value: viewModel.progress)
                .tint(Color.appPrimary)
        }
    }

    // MARK: - Price Summary Section

    private var priceSummarySection: some View {
        Section {
            if viewModel.totalPrice > 0 {
                HStack {
                    Text(String(localized: "items.totalRemaining"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatPrice(viewModel.totalPrice))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.appPrimary)
                }
            }

            if viewModel.totalBoughtPrice > 0 {
                HStack {
                    Text(String(localized: "items.totalBought"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatPrice(viewModel.totalBoughtPrice))
                        .font(.subheadline)
                        .foregroundStyle(Color.appSuccess)
                }
            }
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        Section {
            ForEach(viewModel.sortedItems) { item in
                Button {
                    coordinator.navigateToItemDetail(item)
                } label: {
                    ItemRowView(item: item)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button {
                        Task {
                            await viewModel.toggleItemBought(item)
                        }
                    } label: {
                        Label(
                            item.bought
                                ? String(localized: "item.markUnbought")
                                : String(localized: "item.markBought"),
                            systemImage: item.bought ? "xmark.circle" : "checkmark.circle"
                        )
                    }
                    .tint(item.bought ? .orange : Color.appSuccess)
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
                    .tint(Color.appPrimary)
                }
            }
        } header: {
            HStack {
                Text(String(localized: "items.section.title"))
                Spacer()
                if viewModel.hasUnsyncedChanges {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(String(localized: "offline.banner"))
        }
        .font(.footnote.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appWarning)
        .clipShape(Capsule())
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: viewModel.isOffline)
    }

    // MARK: - Helpers

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB" // Default to RUB for wishlist total
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    // MARK: - Actions

    private func setupDependencies() {
        if let apiClient = apiClient,
           let dataController = dataController,
           let networkMonitor = networkMonitor {
            viewModel.setDependencies(
                apiClient: apiClient,
                dataController: dataController,
                networkMonitor: networkMonitor
            )
        }
    }

    private func deleteItem(_ item: WishlistItem) {
        coordinator.showAlert(
            AlertItem.confirmation(
                title: String(localized: "item.delete.title"),
                message: String(localized: "item.delete.message"),
                confirmTitle: String(localized: "button.delete"),
                onConfirm: {
                    Task {
                        try? await viewModel.deleteItem(item)
                    }
                }
            )
        )
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
                .foregroundStyle(item.bought ? Color.appSuccess : .secondary)

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
                            .foregroundStyle(Color.appPrimary)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
        .accessibilityValue(item.bought ? String(localized: "item.status.bought") : String(localized: "item.status.available"))
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
        case .high: return Color.appError
        case .medium: return Color.appWarning
        case .low: return Color.appInfo
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

#Preview("Empty Items") {
    NavigationStack {
        EmptyItemsView {
            // Add action
        }
        .navigationTitle("Birthday Wishlist")
    }
}
