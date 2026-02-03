import Foundation
import Observation
import UIKit

// MARK: - Sharing View Model

@Observable
@MainActor
final class SharingViewModel {

    // MARK: - Dependencies

    private var apiClient: APIClient?
    private var dataController: DataController?
    private var networkMonitor: NetworkMonitor?

    // MARK: - State

    private(set) var isLoading: Bool = false
    private(set) var error: AppError?
    private(set) var sharedWishlist: WishlistDTO?
    private(set) var isFollowing: Bool = false
    private(set) var isUnfollowing: Bool = false

    // MARK: - Computed Properties

    var shareURL: URL? {
        guard let wishlist = sharedWishlist else { return nil }
        return URL(string: "https://wishwith.me/wishlists/follow/\(wishlist.sharedToken)")
    }

    var isOffline: Bool {
        !(networkMonitor?.isConnected ?? true)
    }

    // MARK: - Initialization

    init(
        apiClient: APIClient? = nil,
        dataController: DataController? = nil,
        networkMonitor: NetworkMonitor? = nil
    ) {
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

    // MARK: - Load Wishlist by Token

    func loadWishlist(token: String) async {
        guard let apiClient = apiClient else {
            error = .unknown
            return
        }

        guard !isOffline else {
            error = .offline
            return
        }

        isLoading = true
        error = nil

        do {
            sharedWishlist = try await apiClient.getWishlistByToken(token)
        } catch {
            self.error = AppError(from: error)
        }

        isLoading = false
    }

    // MARK: - Follow Wishlist

    func followWishlist(token: String) async -> Bool {
        guard let apiClient = apiClient,
              let dataController = dataController else {
            error = .unknown
            return false
        }

        guard !isOffline else {
            error = .offline
            return false
        }

        isFollowing = true
        error = nil

        do {
            let dto = try await apiClient.followWishlist(token: token)
            let _ = try dataController.saveWishlist(dto)
            isFollowing = false
            return true
        } catch {
            self.error = AppError(from: error)
            isFollowing = false
            return false
        }
    }

    // MARK: - Unfollow Wishlist

    func unfollowWishlist(id: String) async -> Bool {
        guard let apiClient = apiClient else {
            error = .unknown
            return false
        }

        guard !isOffline else {
            error = .offline
            return false
        }

        isUnfollowing = true
        error = nil

        do {
            try await apiClient.unfollowWishlist(id: id)
            isUnfollowing = false
            return true
        } catch {
            self.error = AppError(from: error)
            isUnfollowing = false
            return false
        }
    }

    // MARK: - Generate Share URL

    static func generateShareURL(for wishlist: Wishlist) -> URL? {
        URL(string: "https://wishwith.me/wishlists/follow/\(wishlist.sharedToken)")
    }

    // MARK: - Copy to Clipboard

    func copyLinkToClipboard(for wishlist: Wishlist) -> Bool {
        guard let url = Self.generateShareURL(for: wishlist) else { return false }
        UIPasteboard.general.string = url.absoluteString
        return true
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}

// MARK: - Shared Wishlists View Model

@Observable
@MainActor
final class SharedWishlistsViewModel {

    // MARK: - Dependencies

    private var apiClient: APIClient?
    private var dataController: DataController?
    private var networkMonitor: NetworkMonitor?

    // MARK: - State

    private(set) var wishlists: [WishlistDTO] = []
    private(set) var isLoading: Bool = false
    private(set) var isRefreshing: Bool = false
    private(set) var error: AppError?

    // MARK: - Computed Properties

    var isEmpty: Bool {
        wishlists.isEmpty
    }

    var isOffline: Bool {
        !(networkMonitor?.isConnected ?? true)
    }

    // MARK: - Initialization

    init(
        apiClient: APIClient? = nil,
        dataController: DataController? = nil,
        networkMonitor: NetworkMonitor? = nil
    ) {
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

    // MARK: - Load Shared Wishlists

    func loadWishlists() async {
        guard !isLoading else { return }
        guard let apiClient = apiClient else {
            error = .unknown
            return
        }

        isLoading = true
        error = nil

        if networkMonitor?.isConnected ?? false {
            do {
                wishlists = try await apiClient.getSharedWishlists()
            } catch {
                self.error = AppError(from: error)
            }
        } else {
            error = .offline
        }

        isLoading = false
    }

    // MARK: - Refresh Shared Wishlists

    func refreshWishlists() async {
        guard !isRefreshing else { return }
        guard let apiClient = apiClient else { return }

        isRefreshing = true
        error = nil

        if networkMonitor?.isConnected ?? false {
            do {
                wishlists = try await apiClient.getSharedWishlists()
            } catch {
                // Don't show error on refresh if we have data
                if wishlists.isEmpty {
                    self.error = AppError(from: error)
                }
            }
        }

        isRefreshing = false
    }

    // MARK: - Unfollow Wishlist

    func unfollowWishlist(id: String) async -> Bool {
        guard let apiClient = apiClient else {
            error = .unknown
            return false
        }

        guard networkMonitor?.isConnected ?? false else {
            error = .offline
            return false
        }

        do {
            try await apiClient.unfollowWishlist(id: id)
            wishlists.removeAll { $0.id == id }
            return true
        } catch {
            self.error = AppError(from: error)
            return false
        }
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}
