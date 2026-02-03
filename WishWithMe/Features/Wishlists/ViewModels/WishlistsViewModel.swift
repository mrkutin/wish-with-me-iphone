import Foundation
import Observation
import SwiftData

// MARK: - Wishlists View Model

@Observable
@MainActor
final class WishlistsViewModel {

    // MARK: - Dependencies

    private var apiClient: APIClient?
    private var dataController: DataController?
    private var networkMonitor: NetworkMonitor?
    private var authManager: AuthManager?

    // MARK: - State

    private(set) var wishlists: [Wishlist] = []
    private(set) var isLoading: Bool = false
    private(set) var isRefreshing: Bool = false
    private(set) var error: AppError?
    private(set) var isOffline: Bool = false

    // MARK: - Search & Filter

    var searchText: String = ""

    var filteredWishlists: [Wishlist] {
        let nonDeleted = wishlists.filter { !$0.pendingDeletion }

        if searchText.isEmpty {
            return nonDeleted
        }

        return nonDeleted.filter { wishlist in
            wishlist.name.localizedCaseInsensitiveContains(searchText) ||
            (wishlist.wishlistDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var isEmpty: Bool {
        wishlists.filter { !$0.pendingDeletion }.isEmpty
    }

    var hasUnsyncedChanges: Bool {
        wishlists.contains { $0.needsSync }
    }

    // MARK: - Initialization

    init(
        apiClient: APIClient? = nil,
        dataController: DataController? = nil,
        networkMonitor: NetworkMonitor? = nil,
        authManager: AuthManager? = nil
    ) {
        self.apiClient = apiClient
        self.dataController = dataController
        self.networkMonitor = networkMonitor
        self.authManager = authManager
    }

    func setDependencies(
        apiClient: APIClient,
        dataController: DataController,
        networkMonitor: NetworkMonitor,
        authManager: AuthManager
    ) {
        self.apiClient = apiClient
        self.dataController = dataController
        self.networkMonitor = networkMonitor
        self.authManager = authManager
    }

    // MARK: - Load Wishlists

    /// Loads wishlists from local cache first, then fetches from API
    func loadWishlists() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        isOffline = !(networkMonitor?.isConnected ?? true)

        // Load from local cache first
        loadFromCache()

        // If online, fetch from API
        if networkMonitor?.isConnected ?? false {
            await fetchFromAPI()
        }

        isLoading = false
    }

    /// Refreshes wishlists from API (pull-to-refresh)
    func refreshWishlists() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        error = nil
        isOffline = !(networkMonitor?.isConnected ?? true)

        if networkMonitor?.isConnected ?? false {
            await fetchFromAPI()
        } else {
            loadFromCache()
        }

        isRefreshing = false
    }

    private func loadFromCache() {
        do {
            wishlists = try dataController?.getAllWishlists() ?? []
        } catch {
            self.error = AppError(from: error)
        }
    }

    private func fetchFromAPI() async {
        guard let apiClient = apiClient else { return }

        do {
            let dtos = try await apiClient.getWishlists()
            let _ = try dataController?.saveWishlists(dtos)
            loadFromCache() // Reload from cache to get updated data
        } catch {
            // If we have cached data, don't show error
            if wishlists.isEmpty {
                self.error = AppError(from: error)
            }
        }
    }

    // MARK: - Create Wishlist

    /// Creates a new wishlist with optimistic update
    func createWishlist(name: String, description: String?, dueDate: Date?) async throws -> Wishlist {
        guard let dataController = dataController else {
            throw APIError.unknown
        }

        let userId = authManager?.currentUser?.id ?? ""
        let userName = authManager?.currentUser?.name ?? ""

        // Create locally first (optimistic update)
        let wishlist = try dataController.createWishlist(
            name: name,
            description: description,
            dueDate: dueDate,
            userId: userId,
            userName: userName
        )

        // Reload cache
        loadFromCache()

        // Sync to server if online
        if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
            let dateFormatter = ISO8601DateFormatter()
            let dueDateString = dueDate.map { dateFormatter.string(from: $0) }

            let request = CreateWishlistRequest(
                name: name,
                description: description,
                dueDate: dueDateString
            )

            do {
                let dto = try await apiClient.createWishlist(request)

                // Update local wishlist with server response
                wishlist.id = dto.id
                wishlist.sharedToken = dto.sharedToken
                wishlist.needsSync = false
                try dataController.save()

                // Reload cache with updated data
                loadFromCache()
            } catch {
                // Keep local version, will sync later
                wishlist.needsSync = true
                try dataController.save()
            }
        }

        return wishlist
    }

    // MARK: - Update Wishlist

    /// Updates an existing wishlist with optimistic update
    func updateWishlist(_ wishlist: Wishlist, name: String?, description: String?, dueDate: Date?) async throws {
        guard let dataController = dataController else {
            throw APIError.unknown
        }

        // Update locally first (optimistic update)
        try dataController.updateWishlist(
            wishlist,
            name: name,
            description: description,
            dueDate: dueDate
        )

        // Reload cache
        loadFromCache()

        // Sync to server if online
        if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
            let dateFormatter = ISO8601DateFormatter()
            let dueDateString = dueDate.map { dateFormatter.string(from: $0) }

            let request = UpdateWishlistRequest(
                name: name,
                description: description,
                dueDate: dueDateString
            )

            do {
                let _ = try await apiClient.updateWishlist(id: wishlist.id, request: request)
                wishlist.needsSync = false
                try dataController.save()
            } catch {
                // Keep local version, will sync later
                wishlist.needsSync = true
            }
        }
    }

    // MARK: - Delete Wishlist

    /// Deletes a wishlist with optimistic update
    func deleteWishlist(_ wishlist: Wishlist) async throws {
        guard let dataController = dataController else {
            throw APIError.unknown
        }

        // Mark for deletion locally first (optimistic update)
        try dataController.markWishlistForDeletion(wishlist)

        // Reload cache
        loadFromCache()

        // Sync to server if online
        if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
            do {
                try await apiClient.deleteWishlist(id: wishlist.id)
                try dataController.deleteWishlist(wishlist)
                loadFromCache()
            } catch {
                // Revert the deletion mark if API fails
                wishlist.pendingDeletion = false
                wishlist.needsSync = true
                try dataController.save()
                loadFromCache()
                throw error
            }
        }
    }

    // MARK: - Sync

    /// Syncs all pending changes to the server
    func syncPendingChanges() async {
        guard networkMonitor?.isConnected ?? false,
              let apiClient = apiClient,
              let dataController = dataController else {
            return
        }

        // Sync wishlists marked for deletion
        let deletedWishlists = wishlists.filter { $0.pendingDeletion }
        for wishlist in deletedWishlists {
            do {
                try await apiClient.deleteWishlist(id: wishlist.id)
                try dataController.deleteWishlist(wishlist)
            } catch {
                // Will retry on next sync
            }
        }

        // Sync wishlists that need sync
        do {
            let needsSync = try dataController.getWishlistsNeedingSync()
            for wishlist in needsSync where !wishlist.pendingDeletion {
                let dateFormatter = ISO8601DateFormatter()
                let dueDateString = wishlist.dueDate.map { dateFormatter.string(from: $0) }

                let request = UpdateWishlistRequest(
                    name: wishlist.name,
                    description: wishlist.wishlistDescription,
                    dueDate: dueDateString
                )

                do {
                    let _ = try await apiClient.updateWishlist(id: wishlist.id, request: request)
                    wishlist.needsSync = false
                    try dataController.save()
                } catch {
                    // Will retry on next sync
                }
            }
        } catch {
            // Ignore errors during sync
        }

        loadFromCache()
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }

    func retry() async {
        await loadWishlists()
    }
}
