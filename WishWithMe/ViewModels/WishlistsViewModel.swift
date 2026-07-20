import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class WishlistsViewModel {
    var wishlists: [Wishlist] = []
    var bookmarks: [Bookmark] = []
    var itemCounts: [String: Int] = [:]
    var isLoading: Bool = false
    var errorMessage: String?

    private let modelContext: ModelContext
    var syncEngine: SyncEngine?
    private let authManager: AuthManager

    init(modelContext: ModelContext, syncEngine: SyncEngine?, authManager: AuthManager) {
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.authManager = authManager
    }

    // MARK: - Data Loading

    func loadWishlists() {
        guard let userId = authManager.currentUser?.id else { return }

        do {
            let descriptor = FetchDescriptor<Wishlist>(
                predicate: #Predicate<Wishlist> { wishlist in
                    wishlist.ownerId == userId && wishlist.softDeleted == false
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            wishlists = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load wishlists"
        }

        refreshItemCounts()
        loadBookmarks()
    }

    func loadBookmarks() {
        guard let userId = authManager.currentUser?.id else { return }

        do {
            let descriptor = FetchDescriptor<Bookmark>(
                predicate: #Predicate<Bookmark> { b in
                    b.userId == userId && b.softDeleted == false
                },
                sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
            )
            bookmarks = try modelContext.fetch(descriptor)
        } catch {
            bookmarks = []
        }
    }

    func refreshItemCounts() {
        var counts: [String: Int] = [:]
        for wishlist in wishlists {
            let wishlistId = wishlist.id
            do {
                let descriptor = FetchDescriptor<Item>(
                    predicate: #Predicate<Item> { item in
                        item.wishlistId == wishlistId && item.softDeleted == false
                    }
                )
                counts[wishlistId] = try modelContext.fetchCount(descriptor)
            } catch {
                counts[wishlistId] = 0
            }
        }
        itemCounts = counts
    }

    func itemCount(for wishlist: Wishlist) -> Int {
        itemCounts[wishlist.id] ?? 0
    }

    func itemCount(for bookmark: Bookmark) -> Int {
        guard let wishlistId = bookmark.wishlistId else { return 0 }
        if let cached = itemCounts[wishlistId] { return cached }
        do {
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { item in
                    item.wishlistId == wishlistId && item.softDeleted == false
                }
            )
            let count = try modelContext.fetchCount(descriptor)
            itemCounts[wishlistId] = count
            return count
        } catch {
            return 0
        }
    }

    // MARK: - CRUD Operations

    func createWishlist(name: String, description: String?, icon: String, iconColor: String = "primary") {
        guard let userId = authManager.currentUser?.id else { return }

        let now = ISO8601DateFormatter().string(from: Date())
        let wishlist = Wishlist(
            id: IDGenerator.create(type: "wishlist"),
            ownerId: userId,
            name: name,
            descriptionText: description,
            icon: icon,
            iconColor: iconColor,
            isPublic: false,
            access: [userId],
            createdAt: now,
            updatedAt: now,
            isDirty: true,
            softDeleted: false
        )

        modelContext.insert(wishlist)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to create wishlist"
            return
        }

        loadWishlists()
        syncEngine?.triggerSync()
    }

    func updateWishlist(_ wishlist: Wishlist, name: String, description: String?, icon: String, iconColor: String = "primary") {
        wishlist.name = name
        wishlist.descriptionText = description
        wishlist.icon = icon
        wishlist.iconColor = iconColor
        wishlist.updatedAt = ISO8601DateFormatter().string(from: Date())
        wishlist.isDirty = true

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to update wishlist"
            return
        }

        loadWishlists()
        syncEngine?.triggerSync()
    }

    func deleteWishlist(_ wishlist: Wishlist) {
        wishlist.softDeleted = true
        wishlist.isDirty = true
        wishlist.updatedAt = ISO8601DateFormatter().string(from: Date())

        // Also soft-delete all items in this wishlist
        let wishlistId = wishlist.id
        do {
            let itemDescriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { item in
                    item.wishlistId == wishlistId && item.softDeleted == false
                }
            )
            let items = try modelContext.fetch(itemDescriptor)
            let now = ISO8601DateFormatter().string(from: Date())
            for item in items {
                item.softDeleted = true
                item.isDirty = true
                item.updatedAt = now
            }
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete wishlist"
            return
        }

        loadWishlists()
        syncEngine?.triggerSync()
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        bookmark.softDeleted = true
        bookmark.isDirty = true
        bookmark.updatedAt = ISO8601DateFormatter().string(from: Date())

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to remove bookmark"
            return
        }

        loadBookmarks()
        syncEngine?.triggerSync()
    }

    // MARK: - Sync

    func refresh() async {
        isLoading = true
        await syncEngine?.fullSync()
        loadWishlists()
        isLoading = false
    }
}
