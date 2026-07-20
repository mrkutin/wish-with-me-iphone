import Foundation
import SwiftData
import Observation

extension Notification.Name {
    static let itemsDidChange = Notification.Name("itemsDidChange")
}

@MainActor
@Observable
final class WishlistDetailViewModel {
    var wishlist: Wishlist?
    var items: [Item] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Surprise Mode
    // Marks are NEVER exposed to the wishlist owner.
    // Server enforces this via access arrays (owner excluded),
    // and the client enforces it by only loading marks for non-owners.
    // This property is intentionally empty for owner's own wishlists.
    private(set) var marks: [Mark] = []

    /// Whether the current user is the wishlist owner (marks hidden).
    var isOwner: Bool {
        guard let userId = authManager.currentUser?.id else { return false }
        return wishlist?.ownerId == userId
    }

    private let modelContext: ModelContext
    var syncEngine: SyncEngine?
    private let authManager: AuthManager
    let wishlistId: String

    init(
        wishlistId: String,
        modelContext: ModelContext,
        syncEngine: SyncEngine?,
        authManager: AuthManager
    ) {
        self.wishlistId = wishlistId
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.authManager = authManager
    }

    // MARK: - Data Loading

    func loadData() {
        do {
            let wId = wishlistId
            let wishlistDescriptor = FetchDescriptor<Wishlist>(
                predicate: #Predicate<Wishlist> { w in
                    w.id == wId
                }
            )
            wishlist = try modelContext.fetch(wishlistDescriptor).first

            let itemDescriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { item in
                    item.wishlistId == wId && item.softDeleted == false
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            items = try modelContext.fetch(itemDescriptor)

            // Surprise mode: only load marks if current user is NOT the owner.
            // The server already excludes owner from mark access arrays,
            // but we enforce it client-side as defense-in-depth.
            if !isOwner {
                let markDescriptor = FetchDescriptor<Mark>(
                    predicate: #Predicate<Mark> { mark in
                        mark.wishlistId == wId && mark.softDeleted == false
                    }
                )
                marks = try modelContext.fetch(markDescriptor)
            } else {
                marks = []
            }
        } catch {
            errorMessage = "Failed to load data"
        }
    }

    // MARK: - Item Creation

    func createItemByURL(url: String) {
        guard let userId = authManager.currentUser?.id else { return }

        let access = wishlist?.access ?? [userId]
        let now = ISO8601DateFormatter().string(from: Date())

        // Extract hostname as temporary title
        var title = url
        if let parsed = URL(string: url) {
            title = parsed.host ?? url
        }

        let item = Item(
            id: IDGenerator.create(type: "item"),
            wishlistId: wishlistId,
            ownerId: userId,
            title: title,
            sourceUrl: url,
            status: "pending",
            access: access,
            createdAt: now,
            updatedAt: now,
            isDirty: true,
            softDeleted: false
        )

        modelContext.insert(item)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to create item"
            return
        }

        loadData()
        NotificationCenter.default.post(name: .itemsDidChange, object: nil)
        syncEngine?.triggerSync()
    }

    func createItemManually(
        title: String,
        description: String?,
        price: Double?,
        currency: String?,
        quantity: Int,
        sourceUrl: String?,
        imageBase64: String?
    ) {
        guard let userId = authManager.currentUser?.id else { return }

        let access = wishlist?.access ?? [userId]
        let now = ISO8601DateFormatter().string(from: Date())

        let item = Item(
            id: IDGenerator.create(type: "item"),
            wishlistId: wishlistId,
            ownerId: userId,
            title: title,
            descriptionText: description,
            price: price,
            currency: currency,
            quantity: quantity,
            sourceUrl: sourceUrl,
            imageBase64: imageBase64,
            status: "resolved",
            access: access,
            createdAt: now,
            updatedAt: now,
            isDirty: true,
            softDeleted: false
        )

        modelContext.insert(item)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to create item"
            return
        }

        loadData()
        NotificationCenter.default.post(name: .itemsDidChange, object: nil)
        syncEngine?.triggerSync()
    }

    // MARK: - Item Updates

    func updateItem(
        _ item: Item,
        title: String,
        description: String?,
        price: Double?,
        currency: String?,
        quantity: Int,
        sourceUrl: String?,
        imageBase64: String?
    ) {
        item.title = title
        item.descriptionText = description
        item.price = price
        item.currency = currency
        item.quantity = quantity
        item.sourceUrl = sourceUrl
        if let imageBase64 = imageBase64 {
            item.imageBase64 = imageBase64
        }
        item.updatedAt = ISO8601DateFormatter().string(from: Date())
        item.isDirty = true

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to update item"
            return
        }

        loadData()
        NotificationCenter.default.post(name: .itemsDidChange, object: nil)
        syncEngine?.triggerSync()
    }

    func deleteItem(_ item: Item) {
        item.softDeleted = true
        item.isDirty = true
        item.updatedAt = ISO8601DateFormatter().string(from: Date())

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete item"
            return
        }

        loadData()
        NotificationCenter.default.post(name: .itemsDidChange, object: nil)
        syncEngine?.triggerSync()
    }

    // MARK: - Wishlist Updates

    func updateWishlist(name: String, description: String?, icon: String, iconColor: String = "primary") {
        guard let wishlist = wishlist else { return }

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

        loadData()
        syncEngine?.triggerSync()
    }

    func deleteWishlist() {
        guard let wishlist = wishlist else { return }

        let now = ISO8601DateFormatter().string(from: Date())
        wishlist.softDeleted = true
        wishlist.isDirty = true
        wishlist.updatedAt = now

        // Also soft-delete all items
        for item in items {
            item.softDeleted = true
            item.isDirty = true
            item.updatedAt = now
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete wishlist"
            return
        }

        syncEngine?.triggerSync()
    }

    // MARK: - Marks (Surprise Mode)

    func totalMarked(for item: Item) -> Int {
        marks.filter { $0.itemId == item.id }.reduce(0) { $0 + $1.quantity }
    }

    func isFullyMarked(_ item: Item) -> Bool {
        totalMarked(for: item) >= item.quantity
    }

    // MARK: - Sync

    func refresh() async {
        isLoading = true
        await syncEngine?.fullSync()
        loadData()
        isLoading = false
    }
}
