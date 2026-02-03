import Foundation
import SwiftData
import Observation

// MARK: - Data Controller

@Observable
@MainActor
final class DataController {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init(inMemory: Bool = false) {
        let schema = Schema([
            User.self,
            Wishlist.self,
            WishlistItem.self,
            SyncOperation.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            modelContext = modelContainer.mainContext
            modelContext.autosaveEnabled = true
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    // MARK: - Save

    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    // MARK: - User Operations

    func saveUser(_ dto: UserDTO) throws -> User {
        let fetchDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == dto.id }
        )

        if let existingUser = try modelContext.fetch(fetchDescriptor).first {
            existingUser.name = dto.name
            existingUser.email = dto.email
            existingUser.updatedAt = Date()
            try save()
            return existingUser
        } else {
            let user = User(from: dto)
            modelContext.insert(user)
            try save()
            return user
        }
    }

    func getUser(id: String) throws -> User? {
        let fetchDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(fetchDescriptor).first
    }

    func deleteUser(id: String) throws {
        let fetchDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == id }
        )
        if let user = try modelContext.fetch(fetchDescriptor).first {
            modelContext.delete(user)
            try save()
        }
    }

    // MARK: - Wishlist Operations

    func getAllWishlists() throws -> [Wishlist] {
        let fetchDescriptor = FetchDescriptor<Wishlist>(
            predicate: #Predicate { !$0.pendingDeletion },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(fetchDescriptor)
    }

    func getWishlist(id: String) throws -> Wishlist? {
        let fetchDescriptor = FetchDescriptor<Wishlist>(
            predicate: #Predicate { $0.id == id && !$0.pendingDeletion }
        )
        return try modelContext.fetch(fetchDescriptor).first
    }

    func saveWishlist(_ dto: WishlistDTO) throws -> Wishlist {
        let fetchDescriptor = FetchDescriptor<Wishlist>(
            predicate: #Predicate { $0.id == dto.id }
        )

        if let existingWishlist = try modelContext.fetch(fetchDescriptor).first {
            // Update existing wishlist
            updateWishlist(existingWishlist, from: dto)
            try save()
            return existingWishlist
        } else {
            // Create new wishlist
            let wishlist = Wishlist(from: dto)
            modelContext.insert(wishlist)

            // Insert items
            for item in wishlist.items {
                item.wishlist = wishlist
                modelContext.insert(item)
            }

            try save()
            return wishlist
        }
    }

    func saveWishlists(_ dtos: [WishlistDTO]) throws -> [Wishlist] {
        var wishlists: [Wishlist] = []
        for dto in dtos {
            let wishlist = try saveWishlist(dto)
            wishlists.append(wishlist)
        }
        return wishlists
    }

    func createWishlist(name: String, description: String?, dueDate: Date?, userId: String, userName: String) throws -> Wishlist {
        let wishlist = Wishlist(
            id: UUID().uuidString,
            userId: userId,
            userName: userName,
            name: name,
            wishlistDescription: description,
            dueDate: dueDate,
            sharedToken: UUID().uuidString,
            needsSync: true
        )

        modelContext.insert(wishlist)
        try save()
        return wishlist
    }

    func updateWishlist(_ wishlist: Wishlist, name: String?, description: String?, dueDate: Date?) throws {
        if let name = name {
            wishlist.name = name
        }
        if let description = description {
            wishlist.wishlistDescription = description
        }
        wishlist.dueDate = dueDate
        wishlist.updatedAt = Date()
        wishlist.needsSync = true
        wishlist.localVersion += 1

        try save()
    }

    func markWishlistForDeletion(_ wishlist: Wishlist) throws {
        wishlist.pendingDeletion = true
        wishlist.needsSync = true
        try save()
    }

    func deleteWishlist(_ wishlist: Wishlist) throws {
        modelContext.delete(wishlist)
        try save()
    }

    private func updateWishlist(_ wishlist: Wishlist, from dto: WishlistDTO) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        wishlist.name = dto.name
        wishlist.wishlistDescription = dto.description
        wishlist.dueDate = dto.dueDate.flatMap { dateFormatter.date(from: $0) }
        wishlist.updatedAt = dto.updatedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        wishlist.sharedWith = dto.sharedWith?.map { SharedUser(from: $0) } ?? []

        // Update items
        updateItems(for: wishlist, from: dto.items ?? [])
    }

    private func updateItems(for wishlist: Wishlist, from dtos: [WishlistItemDTO]) {
        let existingIds = Set(wishlist.items.map(\.id))
        let newIds = Set(dtos.map(\.id))

        // Remove items not in new list
        for item in wishlist.items where !newIds.contains(item.id) {
            modelContext.delete(item)
        }

        // Update or add items
        for dto in dtos {
            if let existingItem = wishlist.items.first(where: { $0.id == dto.id }) {
                updateItem(existingItem, from: dto)
            } else {
                let item = WishlistItem(from: dto)
                item.wishlist = wishlist
                modelContext.insert(item)
            }
        }
    }

    // MARK: - Item Operations

    func getItem(id: String) throws -> WishlistItem? {
        let fetchDescriptor = FetchDescriptor<WishlistItem>(
            predicate: #Predicate { $0.id == id && !$0.pendingDeletion }
        )
        return try modelContext.fetch(fetchDescriptor).first
    }

    func addItem(to wishlist: Wishlist, name: String, description: String?, url: String?, price: Double?, currency: String?, image: String?, priority: Priority?, notes: String?) throws -> WishlistItem {
        let item = WishlistItem(
            id: UUID().uuidString,
            name: name,
            itemDescription: description,
            url: url,
            price: price,
            currency: currency,
            image: image,
            priority: priority,
            notes: notes,
            needsSync: true
        )

        item.wishlist = wishlist
        modelContext.insert(item)

        wishlist.updatedAt = Date()
        wishlist.localVersion += 1

        try save()
        return item
    }

    func updateItem(_ item: WishlistItem, name: String?, description: String?, url: String?, price: Double?, currency: String?, image: String?, bought: Bool?, priority: Priority?, notes: String?) throws {
        if let name = name {
            item.name = name
        }
        if let description = description {
            item.itemDescription = description
        }
        if let url = url {
            item.url = url
        }
        if let price = price {
            item.price = price
        }
        if let currency = currency {
            item.currency = currency
        }
        if let image = image {
            item.image = image
        }
        if let bought = bought {
            item.bought = bought
        }
        if let priority = priority {
            item.priority = priority
        }
        if let notes = notes {
            item.notes = notes
        }

        item.updatedAt = Date()
        item.needsSync = true

        if let wishlist = item.wishlist {
            wishlist.updatedAt = Date()
            wishlist.localVersion += 1
        }

        try save()
    }

    func toggleItemBought(_ item: WishlistItem) throws {
        item.bought.toggle()
        item.updatedAt = Date()
        item.needsSync = true

        if let wishlist = item.wishlist {
            wishlist.updatedAt = Date()
        }

        try save()
    }

    func markItemForDeletion(_ item: WishlistItem) throws {
        item.pendingDeletion = true
        item.needsSync = true

        if let wishlist = item.wishlist {
            wishlist.updatedAt = Date()
            wishlist.localVersion += 1
        }

        try save()
    }

    func deleteItem(_ item: WishlistItem) throws {
        modelContext.delete(item)
        try save()
    }

    private func updateItem(_ item: WishlistItem, from dto: WishlistItemDTO) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        item.name = dto.name
        item.itemDescription = dto.description
        item.url = dto.url
        item.price = dto.price
        item.currency = dto.currency
        item.image = dto.image
        item.bought = dto.bought ?? false
        item.priority = dto.priority.flatMap { Priority(rawValue: $0) }
        item.notes = dto.notes
        item.updatedAt = dto.updatedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
    }

    // MARK: - Sync Operations

    func getPendingSyncOperations() throws -> [SyncOperation] {
        let fetchDescriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.statusRawValue == "pending" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(fetchDescriptor)
    }

    func addSyncOperation(_ operation: SyncOperation) throws {
        modelContext.insert(operation)
        try save()
    }

    func deleteSyncOperation(_ operation: SyncOperation) throws {
        modelContext.delete(operation)
        try save()
    }

    func clearCompletedSyncOperations() throws {
        let fetchDescriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.statusRawValue == "completed" }
        )
        let completed = try modelContext.fetch(fetchDescriptor)
        for operation in completed {
            modelContext.delete(operation)
        }
        try save()
    }

    func getWishlistsNeedingSync() throws -> [Wishlist] {
        let fetchDescriptor = FetchDescriptor<Wishlist>(
            predicate: #Predicate { $0.needsSync }
        )
        return try modelContext.fetch(fetchDescriptor)
    }

    func getItemsNeedingSync() throws -> [WishlistItem] {
        let fetchDescriptor = FetchDescriptor<WishlistItem>(
            predicate: #Predicate { $0.needsSync }
        )
        return try modelContext.fetch(fetchDescriptor)
    }

    // MARK: - Clear All Data

    func clearAllData() throws {
        try modelContext.delete(model: SyncOperation.self)
        try modelContext.delete(model: WishlistItem.self)
        try modelContext.delete(model: Wishlist.self)
        try modelContext.delete(model: User.self)
        try save()
    }
}
