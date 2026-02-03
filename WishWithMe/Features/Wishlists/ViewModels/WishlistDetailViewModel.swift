import Foundation
import Observation

// MARK: - Item Sort Option

enum ItemSortOption: String, CaseIterable, Sendable {
    case priority
    case dateAdded
    case name
    case price

    var displayName: String {
        switch self {
        case .priority: return String(localized: "sort.priority")
        case .dateAdded: return String(localized: "sort.dateAdded")
        case .name: return String(localized: "sort.name")
        case .price: return String(localized: "sort.price")
        }
    }
}

// MARK: - Wishlist Detail View Model

@Observable
@MainActor
final class WishlistDetailViewModel {

    // MARK: - Dependencies

    private var apiClient: APIClient?
    private var dataController: DataController?
    private var networkMonitor: NetworkMonitor?

    // MARK: - State

    let wishlist: Wishlist
    private(set) var isLoading: Bool = false
    private(set) var isRefreshing: Bool = false
    private(set) var error: AppError?
    private(set) var isOffline: Bool = false

    // MARK: - Filter & Sort State

    var showBoughtItems: Bool = true
    var sortOption: ItemSortOption = .priority
    var sortAscending: Bool = true

    // MARK: - Computed Properties

    var items: [WishlistItem] {
        wishlist.items.filter { !$0.pendingDeletion }
    }

    var sortedItems: [WishlistItem] {
        let filtered = items.filter { showBoughtItems || !$0.bought }

        return filtered.sorted { item1, item2 in
            // Always sort bought items to the bottom
            if item1.bought != item2.bought {
                return !item1.bought
            }

            let result: Bool
            switch sortOption {
            case .priority:
                let priority1 = item1.priority?.sortOrder ?? 3
                let priority2 = item2.priority?.sortOrder ?? 3
                if priority1 != priority2 {
                    result = priority1 < priority2
                } else {
                    result = item1.createdAt > item2.createdAt
                }
            case .dateAdded:
                result = item1.createdAt > item2.createdAt
            case .name:
                result = item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            case .price:
                let price1 = item1.price ?? 0
                let price2 = item2.price ?? 0
                result = price1 < price2
            }

            return sortAscending ? result : !result
        }
    }

    var boughtCount: Int {
        items.filter { $0.bought }.count
    }

    var totalCount: Int {
        items.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(boughtCount) / Double(totalCount)
    }

    var totalPrice: Double {
        items.filter { !$0.bought }.compactMap { $0.price }.reduce(0, +)
    }

    var totalBoughtPrice: Double {
        items.filter { $0.bought }.compactMap { $0.price }.reduce(0, +)
    }

    var hasUnsyncedChanges: Bool {
        items.contains { $0.needsSync }
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    // MARK: - Initialization

    init(
        wishlist: Wishlist,
        apiClient: APIClient? = nil,
        dataController: DataController? = nil,
        networkMonitor: NetworkMonitor? = nil
    ) {
        self.wishlist = wishlist
        self.apiClient = apiClient
        self.dataController = dataController
        self.networkMonitor = networkMonitor
    }

    func setDependencies(
        apiClient: APIClient,
        dataController: DataController,
        networkMonitor: NetworkMonitor
    ) {
        self.apiClient = apiClient
        self.dataController = dataController
        self.networkMonitor = networkMonitor
    }

    // MARK: - Refresh

    /// Refreshes wishlist details from API
    func refreshWishlist() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        error = nil
        isOffline = !(networkMonitor?.isConnected ?? true)

        if networkMonitor?.isConnected ?? false {
            await fetchFromAPI()
        }

        isRefreshing = false
    }

    private func fetchFromAPI() async {
        guard let apiClient = apiClient, let dataController = dataController else { return }

        do {
            let dto = try await apiClient.getWishlist(id: wishlist.id)
            let _ = try dataController.saveWishlist(dto)
        } catch {
            // Silently fail for refresh - user still sees cached data
            if items.isEmpty {
                self.error = AppError(from: error)
            }
        }
    }

    // MARK: - Add Item

    /// Adds a new item to the wishlist with optimistic update
    func addItem(
        name: String,
        description: String?,
        url: String?,
        price: Double?,
        currency: String?,
        image: String?,
        priority: Priority?,
        notes: String?
    ) async throws -> WishlistItem {
        guard let dataController = dataController else {
            throw APIError.unknown
        }

        // Create locally first (optimistic update)
        let item = try dataController.addItem(
            to: wishlist,
            name: name,
            description: description,
            url: url,
            price: price,
            currency: currency,
            image: image,
            priority: priority,
            notes: notes
        )

        // Sync to server if online
        if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
            let request = AddItemRequest(
                name: name,
                description: description,
                url: url,
                price: price,
                currency: currency,
                image: image,
                priority: priority?.rawValue,
                notes: notes
            )

            do {
                let dto = try await apiClient.addItem(wishlistId: wishlist.id, request: request)

                // Update with server response
                if let newItem = dto.items?.first(where: { $0.name == name }) {
                    item.id = newItem.id
                }
                item.needsSync = false
                try dataController.save()
            } catch {
                // Keep local version, will sync later
                item.needsSync = true
                try dataController.save()
            }
        }

        return item
    }

    /// Adds an item by resolving URL first
    func addItemFromURL(_ url: String) async throws -> WishlistItem {
        guard let apiClient = apiClient else {
            throw APIError.unknown
        }

        isLoading = true
        defer { isLoading = false }

        // Resolve URL to get item details
        let resolved = try await apiClient.resolveItem(url: url)

        // Add the item with resolved details
        return try await addItem(
            name: resolved.name ?? extractNameFromURL(url),
            description: resolved.description,
            url: resolved.url,
            price: resolved.price,
            currency: resolved.currency,
            image: resolved.image,
            priority: nil,
            notes: nil
        )
    }

    private func extractNameFromURL(_ url: String) -> String {
        // Try to extract a meaningful name from URL
        guard let urlObj = URL(string: url) else {
            return String(localized: "item.untitled")
        }

        // Get last path component and clean it up
        var name = urlObj.lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        // Remove file extension if present
        if let dotIndex = name.lastIndex(of: ".") {
            name = String(name[..<dotIndex])
        }

        // Capitalize words
        name = name.capitalized

        return name.isEmpty ? String(localized: "item.untitled") : name
    }

    // MARK: - Update Item

    /// Updates an existing item with optimistic update
    func updateItem(
        _ item: WishlistItem,
        name: String?,
        description: String?,
        url: String?,
        price: Double?,
        currency: String?,
        image: String?,
        bought: Bool?,
        priority: Priority?,
        notes: String?
    ) async throws {
        guard let dataController = dataController else {
            throw APIError.unknown
        }

        // Update locally first (optimistic update)
        try dataController.updateItem(
            item,
            name: name,
            description: description,
            url: url,
            price: price,
            currency: currency,
            image: image,
            bought: bought,
            priority: priority,
            notes: notes
        )

        // Sync to server if online
        if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
            let request = UpdateItemRequest(
                name: name,
                description: description,
                url: url,
                price: price,
                currency: currency,
                image: image,
                bought: bought,
                priority: priority?.rawValue,
                notes: notes
            )

            do {
                let _ = try await apiClient.updateItem(
                    wishlistId: wishlist.id,
                    itemId: item.id,
                    request: request
                )
                item.needsSync = false
                try dataController.save()
            } catch {
                // Keep local version, will sync later
                item.needsSync = true
            }
        }
    }

    // MARK: - Toggle Item Bought

    /// Toggles the bought status of an item
    func toggleItemBought(_ item: WishlistItem) async {
        guard let dataController = dataController else { return }

        do {
            try dataController.toggleItemBought(item)

            // Sync to server if online
            if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
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

                do {
                    let _ = try await apiClient.updateItem(
                        wishlistId: wishlist.id,
                        itemId: item.id,
                        request: request
                    )
                    item.needsSync = false
                    try dataController.save()
                } catch {
                    // Keep local version, will sync later
                    item.needsSync = true
                }
            }
        } catch {
            self.error = AppError(from: error)
        }
    }

    // MARK: - Delete Item

    /// Deletes an item with optimistic update
    func deleteItem(_ item: WishlistItem) async throws {
        guard let dataController = dataController else {
            throw APIError.unknown
        }

        // Mark for deletion locally first (optimistic update)
        try dataController.markItemForDeletion(item)

        // Sync to server if online
        if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
            do {
                try await apiClient.deleteItem(wishlistId: wishlist.id, itemId: item.id)
                try dataController.deleteItem(item)
            } catch {
                // Revert the deletion mark if API fails
                item.pendingDeletion = false
                item.needsSync = true
                try dataController.save()
                throw error
            }
        }
    }

    // MARK: - URL Resolution

    /// Resolves a URL to get item details
    func resolveURL(_ url: String) async throws -> ResolveItemResponse {
        guard let apiClient = apiClient else {
            throw APIError.unknown
        }

        isLoading = true
        defer { isLoading = false }

        return try await apiClient.resolveItem(url: url)
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }

    func retry() async {
        await refreshWishlist()
    }
}
