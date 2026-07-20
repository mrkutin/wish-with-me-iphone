import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SharedWishlistViewModel {
    var wishlist: Wishlist?
    var items: [Item] = []
    var marks: [Mark] = []
    var bookmark: Bookmark?
    var isLoading: Bool = false
    var errorMessage: String?
    var grantSuccess: Bool = false
    var permissions: [String] = []

    private let modelContext: ModelContext
    var syncEngine: SyncEngine?
    private let authManager: AuthManager

    private var wishlistId: String?

    init(
        modelContext: ModelContext,
        syncEngine: SyncEngine?,
        authManager: AuthManager,
        wishlistId: String? = nil
    ) {
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.authManager = authManager
        self.wishlistId = wishlistId
    }

    // MARK: - Grant Access Flow (from deep link)

    func grantAccessAndSync(token: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.grantAccess(token: token)
            wishlistId = response.wishlistId
            permissions = response.permissions
            grantSuccess = true

            await syncEngine?.fullSync()
            loadData()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Load from SwiftData (from bookmark)

    func loadFromBookmark(wishlistId: String) {
        self.wishlistId = wishlistId
        loadData()
    }

    func loadData() {
        guard let wId = wishlistId else { return }

        do {
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

            let markDescriptor = FetchDescriptor<Mark>(
                predicate: #Predicate<Mark> { mark in
                    mark.wishlistId == wId && mark.softDeleted == false
                }
            )
            marks = try modelContext.fetch(markDescriptor)

            // Load bookmark
            guard let userId = authManager.currentUser?.id else { return }
            let bookmarkDescriptor = FetchDescriptor<Bookmark>(
                predicate: #Predicate<Bookmark> { b in
                    b.wishlistId == wId && b.userId == userId && b.softDeleted == false
                }
            )
            bookmark = try modelContext.fetch(bookmarkDescriptor).first
        } catch {
            errorMessage = "Failed to load data"
        }
    }

    // MARK: - Mark / Unmark

    func markItem(_ item: Item) {
        guard let userId = authManager.currentUser?.id,
              let wishlist = wishlist else { return }

        let now = ISO8601DateFormatter().string(from: Date())

        // Access = all wishlist viewers EXCEPT the owner (surprise mode)
        let markAccess = wishlist.access.filter { $0 != wishlist.ownerId }

        let mark = Mark(
            id: IDGenerator.create(type: "mark"),
            itemId: item.id,
            wishlistId: wishlist.id,
            ownerId: wishlist.ownerId,
            markedBy: userId,
            quantity: 1,
            access: markAccess,
            createdAt: now,
            updatedAt: now,
            isDirty: true,
            softDeleted: false
        )

        modelContext.insert(mark)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to mark item"
            return
        }

        loadData()
        syncEngine?.triggerSync()
    }

    func unmarkItem(_ item: Item) {
        guard let mark = myMarkForItem(item) else { return }

        mark.softDeleted = true
        mark.isDirty = true
        mark.updatedAt = ISO8601DateFormatter().string(from: Date())

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to unmark item"
            return
        }

        loadData()
        syncEngine?.triggerSync()
    }

    // MARK: - Helpers

    func myMarkForItem(_ item: Item) -> Mark? {
        guard let userId = authManager.currentUser?.id else { return nil }
        return marks.first { $0.itemId == item.id && $0.markedBy == userId }
    }

    func totalMarked(for item: Item) -> Int {
        marks.filter { $0.itemId == item.id }.reduce(0) { $0 + $1.quantity }
    }

    func isFullyMarked(_ item: Item) -> Bool {
        totalMarked(for: item) >= item.quantity
    }

    func canMark(_ item: Item) -> Bool {
        guard myMarkForItem(item) == nil else { return false }
        return !isFullyMarked(item)
    }

    var canMarkItems: Bool {
        permissions.contains("mark") || permissions.isEmpty
    }

    // MARK: - Sync

    func refresh() async {
        isLoading = true
        await syncEngine?.fullSync()
        loadData()
        isLoading = false
    }
}
