import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SyncEngine {
    enum SyncState: Equatable {
        case idle
        case syncing
        case error(String)
        case offline

        static func == (lhs: SyncState, rhs: SyncState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.offline, .offline):
                return true
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }

    var state: SyncState = .idle

    private let apiClient: APIClient
    private let modelContainer: ModelContainer
    private let networkMonitor: NetworkMonitor
    private var failedPushDocIds: Set<String> = []

    private var syncTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?
    private static let debounceInterval: TimeInterval = 1.0
    private static let periodicInterval: TimeInterval = 30.0

    private let pushCollections = ["wishlists", "items", "marks", "bookmarks", "users", "shares"]
    private let pullCollections = ["wishlists", "items", "marks", "bookmarks", "users", "shares"]

    init(apiClient: APIClient, modelContainer: ModelContainer, networkMonitor: NetworkMonitor) {
        self.apiClient = apiClient
        self.modelContainer = modelContainer
        self.networkMonitor = networkMonitor
    }

    // MARK: - Public API

    func startPeriodicSync() {
        periodicTask?.cancel()
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.periodicInterval))
                guard !Task.isCancelled else { return }
                await self?.fullSync()
            }
        }
    }

    func stopSync() {
        periodicTask?.cancel()
        syncTask?.cancel()
    }

    func triggerSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.debounceInterval))
            guard !Task.isCancelled else { return }
            await self?.fullSync()
        }
    }

    func fullSync() async {
        guard networkMonitor.isConnected else {
            state = .offline
            return
        }

        state = .syncing

        do {
            try await pushAll()
            try await pullAndReconcileAll()
            state = .idle
        } catch {
            if error is CancellationError { return }
            NSLog("[Sync] Error: %@", String(describing: error))
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Push

    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    private func pushAll() async throws {
        failedPushDocIds = []
        let context = mainContext

        for collection in pushCollections {
            let dirtyDTOs = try getDirtyDTOs(collection: collection, context: context)
            if dirtyDTOs.isEmpty { continue }

            let request = SyncPushRequest(documents: dirtyDTOs)
            let response: SyncPushResponse = try await apiClient.request(
                endpoint: "/api/v2/sync/push/\(collection)",
                method: "POST",
                body: request
            )

            let conflictIds = Set(response.conflicts.map(\.documentId))
            for conflict in response.conflicts {
                if conflict.serverDocument == nil {
                    failedPushDocIds.insert(conflict.documentId)
                }
            }

            try markClean(collection: collection, excludeIds: conflictIds, context: context)
        }

        try context.save()
    }

    // MARK: - Pull and Reconcile

    private func pullAndReconcileAll() async throws {
        let context = mainContext
        var pulledIds: [String: Set<String>] = [:]

        for collection in pullCollections {
            let response: SyncPullResponse = try await apiClient.request(
                endpoint: "/api/v2/sync/pull/\(collection)",
                method: "GET"
            )

            let serverDocDicts = response.documents
            let serverIds = Set(serverDocDicts.compactMap { dict -> String? in
                (dict["_id"]?.value as? String)
            })

            for docDict in serverDocDicts {
                do {
                    try upsertFromServer(collection: collection, docDict: docDict, context: context)
                } catch {
                    let docId = (docDict["_id"]?.value as? String) ?? "unknown"
                    NSLog("[Sync] Decode error in %@ doc %@: %@", collection, docId, String(describing: error))
                    // Continue with other docs instead of failing the entire sync
                    continue
                }
            }

            pulledIds[collection] = serverIds
        }

        try context.save()

        for (collection, serverIds) in pulledIds {
            let localIds = try getAllLocalIds(collection: collection, context: context)
            let dirtyIds = try getDirtyLocalIds(collection: collection, context: context)
            let orphans = localIds.subtracting(serverIds).subtracting(failedPushDocIds).subtracting(dirtyIds)

            for orphanId in orphans {
                try deleteLocal(id: orphanId, collection: collection, context: context)
            }
        }

        try context.save()
    }

    // MARK: - Helper Methods

    private func getDirtyDTOs(collection: String, context: ModelContext) throws -> [[String: AnyCodable]] {
        var dtos: [[String: AnyCodable]] = []

        switch collection {
        case "wishlists":
            let descriptor = FetchDescriptor<Wishlist>(predicate: #Predicate { $0.isDirty })
            let wishlists = try context.fetch(descriptor)
            dtos = try wishlists.map { try dtoToDict($0.toDTO()) }
        case "items":
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.isDirty })
            let items = try context.fetch(descriptor)
            dtos = try items.map { try dtoToDict($0.toDTO()) }
        case "marks":
            let descriptor = FetchDescriptor<Mark>(predicate: #Predicate { $0.isDirty })
            let marks = try context.fetch(descriptor)
            dtos = try marks.map { try dtoToDict($0.toDTO()) }
        case "bookmarks":
            let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.isDirty })
            let bookmarks = try context.fetch(descriptor)
            dtos = try bookmarks.map { try dtoToDict($0.toDTO()) }
        case "users":
            let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.isDirty })
            let users = try context.fetch(descriptor)
            dtos = try users.map { try dtoToDict($0.toDTO()) }
        case "shares":
            let descriptor = FetchDescriptor<Share>(predicate: #Predicate { $0.isDirty })
            let shares = try context.fetch(descriptor)
            dtos = try shares.map { try dtoToDict($0.toDTO()) }
        default:
            break
        }

        return dtos
    }

    private func dtoToDict<T: Encodable>(_ dto: T) throws -> [String: AnyCodable] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(dto)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let dict = jsonObject as? [String: Any] else {
            throw NSError(domain: "SyncEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert DTO to dict"])
        }
        return dict.mapValues { AnyCodable($0) }
    }

    private func upsertFromServer(collection: String, docDict: [String: AnyCodable], context: ModelContext) throws {
        guard let id = docDict["_id"]?.value as? String else { return }

        let jsonData = try JSONSerialization.data(withJSONObject: docDict.mapValues(\.value))

        switch collection {
        case "wishlists":
            let dto = try JSONDecoder().decode(WishlistDTO.self, from: jsonData)
            let descriptor = FetchDescriptor<Wishlist>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                // Skip upsert if local doc has pending changes (push-first protocol)
                guard !existing.isDirty else { return }
                existing.rev = dto.rev
                existing.name = dto.name
                existing.descriptionText = dto.descriptionText
                existing.icon = dto.icon ?? existing.icon
                existing.iconColor = dto.iconColor
                existing.isPublic = dto.isPublic
                existing.access = dto.access
                existing.updatedAt = dto.updatedAt
                existing.isDirty = false
                existing.lastSyncedAt = Date()
            } else {
                context.insert(Wishlist(from: dto))
            }
        case "items":
            let dto = try JSONDecoder().decode(ItemDTO.self, from: jsonData)
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                guard !existing.isDirty else { return }
                existing.rev = dto.rev
                existing.title = dto.title
                existing.descriptionText = dto.descriptionText
                existing.price = dto.price
                existing.currency = dto.currency
                existing.quantity = dto.quantity
                existing.sourceUrl = dto.sourceUrl
                existing.imageUrl = dto.imageUrl
                existing.imageBase64 = dto.imageBase64
                existing.status = dto.status
                existing.resolveConfidence = dto.resolveConfidence
                existing.resolveError = dto.resolveError
                existing.resolvedAt = dto.resolvedAt
                existing.access = dto.access
                existing.updatedAt = dto.updatedAt
                existing.isDirty = false
                existing.lastSyncedAt = Date()
            } else {
                context.insert(Item(from: dto))
            }
        case "marks":
            let dto = try JSONDecoder().decode(MarkDTO.self, from: jsonData)
            let descriptor = FetchDescriptor<Mark>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                guard !existing.isDirty else { return }
                existing.rev = dto.rev
                existing.quantity = dto.quantity
                existing.access = dto.access
                existing.updatedAt = dto.updatedAt
                existing.isDirty = false
                existing.lastSyncedAt = Date()
            } else {
                context.insert(Mark(from: dto))
            }
        case "bookmarks":
            let dto = try JSONDecoder().decode(BookmarkDTO.self, from: jsonData)
            let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                guard !existing.isDirty else { return }
                existing.rev = dto.rev
                existing.wishlistId = dto.wishlistId
                existing.ownerName = dto.ownerName
                existing.ownerAvatarBase64 = dto.ownerAvatarBase64
                existing.wishlistName = dto.wishlistName
                existing.wishlistIcon = dto.wishlistIcon
                existing.wishlistIconColor = dto.wishlistIconColor
                existing.access = dto.access
                existing.updatedAt = dto.updatedAt
                existing.lastAccessedAt = dto.lastAccessedAt
                existing.isDirty = false
                existing.lastSyncedAt = Date()
            } else {
                context.insert(Bookmark(from: dto))
            }
        case "users":
            let dto = try JSONDecoder().decode(UserDTO.self, from: jsonData)
            let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                guard !existing.isDirty else { return }
                existing.rev = dto.rev
                existing.email = dto.email
                existing.name = dto.name
                existing.avatarBase64 = dto.avatarBase64
                existing.bio = dto.bio
                existing.publicUrlSlug = dto.publicUrlSlug
                existing.locale = dto.locale
                existing.birthday = dto.birthday
                existing.access = dto.access
                existing.updatedAt = dto.updatedAt
                existing.isDirty = false
                existing.lastSyncedAt = Date()
            } else {
                context.insert(User(from: dto))
            }
        case "shares":
            let dto = try JSONDecoder().decode(ShareDTO.self, from: jsonData)
            let descriptor = FetchDescriptor<Share>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                guard !existing.isDirty else { return }
                existing.rev = dto.rev
                existing.token = dto.token
                existing.linkType = dto.linkType
                existing.expiresAt = dto.expiresAt
                existing.accessCount = dto.accessCount
                existing.revoked = dto.revoked
                existing.grantedUsers = dto.grantedUsers
                existing.access = dto.access
                existing.updatedAt = dto.updatedAt ?? dto.createdAt
                existing.isDirty = false
                existing.lastSyncedAt = Date()
            } else {
                context.insert(Share(from: dto))
            }
        default:
            break
        }
    }

    private func getAllLocalIds(collection: String, context: ModelContext) throws -> Set<String> {
        switch collection {
        case "wishlists":
            let descriptor = FetchDescriptor<Wishlist>()
            return Set(try context.fetch(descriptor).map(\.id))
        case "items":
            let descriptor = FetchDescriptor<Item>()
            return Set(try context.fetch(descriptor).map(\.id))
        case "marks":
            let descriptor = FetchDescriptor<Mark>()
            return Set(try context.fetch(descriptor).map(\.id))
        case "bookmarks":
            let descriptor = FetchDescriptor<Bookmark>()
            return Set(try context.fetch(descriptor).map(\.id))
        case "users":
            let descriptor = FetchDescriptor<User>()
            return Set(try context.fetch(descriptor).map(\.id))
        case "shares":
            let descriptor = FetchDescriptor<Share>()
            return Set(try context.fetch(descriptor).map(\.id))
        default:
            return []
        }
    }

    private func deleteLocal(id: String, collection: String, context: ModelContext) throws {
        switch collection {
        case "wishlists":
            let descriptor = FetchDescriptor<Wishlist>(predicate: #Predicate { $0.id == id })
            if let doc = try context.fetch(descriptor).first {
                context.delete(doc)
            }
        case "items":
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
            if let doc = try context.fetch(descriptor).first {
                context.delete(doc)
            }
        case "marks":
            let descriptor = FetchDescriptor<Mark>(predicate: #Predicate { $0.id == id })
            if let doc = try context.fetch(descriptor).first {
                context.delete(doc)
            }
        case "bookmarks":
            let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == id })
            if let doc = try context.fetch(descriptor).first {
                context.delete(doc)
            }
        case "users":
            let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
            if let doc = try context.fetch(descriptor).first {
                context.delete(doc)
            }
        case "shares":
            let descriptor = FetchDescriptor<Share>(predicate: #Predicate { $0.id == id })
            if let doc = try context.fetch(descriptor).first {
                context.delete(doc)
            }
        default:
            break
        }
    }

    private func getDirtyLocalIds(collection: String, context: ModelContext) throws -> Set<String> {
        switch collection {
        case "wishlists":
            let descriptor = FetchDescriptor<Wishlist>(predicate: #Predicate { $0.isDirty })
            return Set(try context.fetch(descriptor).map(\.id))
        case "items":
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.isDirty })
            return Set(try context.fetch(descriptor).map(\.id))
        case "marks":
            let descriptor = FetchDescriptor<Mark>(predicate: #Predicate { $0.isDirty })
            return Set(try context.fetch(descriptor).map(\.id))
        case "bookmarks":
            let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.isDirty })
            return Set(try context.fetch(descriptor).map(\.id))
        case "users":
            let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.isDirty })
            return Set(try context.fetch(descriptor).map(\.id))
        case "shares":
            let descriptor = FetchDescriptor<Share>(predicate: #Predicate { $0.isDirty })
            return Set(try context.fetch(descriptor).map(\.id))
        default:
            return []
        }
    }

    private func markClean(collection: String, excludeIds: Set<String>, context: ModelContext) throws {
        switch collection {
        case "wishlists":
            let descriptor = FetchDescriptor<Wishlist>(predicate: #Predicate { $0.isDirty })
            let docs = try context.fetch(descriptor)
            for doc in docs where !excludeIds.contains(doc.id) {
                doc.isDirty = false
                doc.lastSyncedAt = Date()
            }
        case "items":
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.isDirty })
            let docs = try context.fetch(descriptor)
            for doc in docs where !excludeIds.contains(doc.id) {
                doc.isDirty = false
                doc.lastSyncedAt = Date()
            }
        case "marks":
            let descriptor = FetchDescriptor<Mark>(predicate: #Predicate { $0.isDirty })
            let docs = try context.fetch(descriptor)
            for doc in docs where !excludeIds.contains(doc.id) {
                doc.isDirty = false
                doc.lastSyncedAt = Date()
            }
        case "bookmarks":
            let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.isDirty })
            let docs = try context.fetch(descriptor)
            for doc in docs where !excludeIds.contains(doc.id) {
                doc.isDirty = false
                doc.lastSyncedAt = Date()
            }
        case "users":
            let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.isDirty })
            let docs = try context.fetch(descriptor)
            for doc in docs where !excludeIds.contains(doc.id) {
                doc.isDirty = false
                doc.lastSyncedAt = Date()
            }
        case "shares":
            let descriptor = FetchDescriptor<Share>(predicate: #Predicate { $0.isDirty })
            let docs = try context.fetch(descriptor)
            for doc in docs where !excludeIds.contains(doc.id) {
                doc.isDirty = false
                doc.lastSyncedAt = Date()
            }
        default:
            break
        }
    }
}
