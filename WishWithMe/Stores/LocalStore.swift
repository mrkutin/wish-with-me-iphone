import Foundation
import SwiftData

@MainActor
final class LocalStore {
    static let shared = LocalStore()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            User.self,
            Wishlist.self,
            Item.self,
            Mark.self,
            Share.self,
            Bookmark.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema migration failed — delete old store and recreate
            let storeURL = modelConfiguration.url
            let storePath = storeURL.path()
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: storePath + suffix)
            }
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }

    func clearAllData() {
        let context = ModelContext(modelContainer)
        do {
            try context.delete(model: User.self)
            try context.delete(model: Wishlist.self)
            try context.delete(model: Item.self)
            try context.delete(model: Mark.self)
            try context.delete(model: Share.self)
            try context.delete(model: Bookmark.self)
            try context.save()
        } catch {
            // Best-effort clear — log but don't crash
            print("LocalStore.clearAllData failed: \(error)")
        }
    }
}
