import Foundation
import SwiftData

// MARK: - Operation Type

enum OperationType: String, Codable, Sendable {
    case create
    case update
    case delete
}

// MARK: - Entity Type

enum EntityType: String, Codable, Sendable {
    case wishlist
    case item
}

// MARK: - Sync Operation Status

enum SyncOperationStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
}

// MARK: - Sync Operation Model (SwiftData)

@Model
final class SyncOperation {
    @Attribute(.unique) var id: UUID
    var operationTypeRawValue: String
    var entityTypeRawValue: String
    var entityId: String
    var parentEntityId: String?
    var payload: Data?
    var statusRawValue: String
    var createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var errorMessage: String?

    // Computed properties for enums
    var operationType: OperationType {
        get { OperationType(rawValue: operationTypeRawValue) ?? .create }
        set { operationTypeRawValue = newValue.rawValue }
    }

    var entityType: EntityType {
        get { EntityType(rawValue: entityTypeRawValue) ?? .wishlist }
        set { entityTypeRawValue = newValue.rawValue }
    }

    var status: SyncOperationStatus {
        get { SyncOperationStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        operationType: OperationType,
        entityType: EntityType,
        entityId: String,
        parentEntityId: String? = nil,
        payload: Data? = nil,
        status: SyncOperationStatus = .pending,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.operationTypeRawValue = operationType.rawValue
        self.entityTypeRawValue = entityType.rawValue
        self.entityId = entityId
        self.parentEntityId = parentEntityId
        self.payload = payload
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
        self.errorMessage = errorMessage
    }

    // MARK: - Factory Methods

    static func createWishlist(id: String, request: CreateWishlistRequest) -> SyncOperation {
        let payload = try? JSONEncoder().encode(request)
        return SyncOperation(
            operationType: .create,
            entityType: .wishlist,
            entityId: id,
            payload: payload
        )
    }

    static func updateWishlist(id: String, request: UpdateWishlistRequest) -> SyncOperation {
        let payload = try? JSONEncoder().encode(request)
        return SyncOperation(
            operationType: .update,
            entityType: .wishlist,
            entityId: id,
            payload: payload
        )
    }

    static func deleteWishlist(id: String) -> SyncOperation {
        return SyncOperation(
            operationType: .delete,
            entityType: .wishlist,
            entityId: id
        )
    }

    static func createItem(id: String, wishlistId: String, request: AddItemRequest) -> SyncOperation {
        let payload = try? JSONEncoder().encode(request)
        return SyncOperation(
            operationType: .create,
            entityType: .item,
            entityId: id,
            parentEntityId: wishlistId,
            payload: payload
        )
    }

    static func updateItem(id: String, wishlistId: String, request: UpdateItemRequest) -> SyncOperation {
        let payload = try? JSONEncoder().encode(request)
        return SyncOperation(
            operationType: .update,
            entityType: .item,
            entityId: id,
            parentEntityId: wishlistId,
            payload: payload
        )
    }

    static func deleteItem(id: String, wishlistId: String) -> SyncOperation {
        return SyncOperation(
            operationType: .delete,
            entityType: .item,
            entityId: id,
            parentEntityId: wishlistId
        )
    }

    // MARK: - Helper Methods

    func incrementRetry() {
        retryCount += 1
        lastAttemptAt = Date()
    }

    func markFailed(with message: String) {
        status = .failed
        errorMessage = message
        lastAttemptAt = Date()
    }

    func markCompleted() {
        status = .completed
        lastAttemptAt = Date()
    }

    var canRetry: Bool {
        retryCount < 3 && status != .completed
    }
}
