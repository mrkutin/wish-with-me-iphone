import Foundation
import SwiftData

// MARK: - Operation Queue Manager

@MainActor
final class OperationQueueManager {

    // MARK: - Properties

    private let dataController: DataController

    // MARK: - Initialization

    init(dataController: DataController) {
        self.dataController = dataController
    }

    // MARK: - CRUD Operations

    /// Adds a new operation to the queue
    func addOperation(_ operation: SyncOperation) throws {
        dataController.modelContext.insert(operation)
        try dataController.save()
    }

    /// Gets all pending operations ordered by creation date
    func getPendingOperations() throws -> [SyncOperation] {
        let fetchDescriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { operation in
                operation.statusRawValue == "pending" || operation.statusRawValue == "inProgress"
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try dataController.modelContext.fetch(fetchDescriptor)
    }

    /// Gets all failed operations
    func getFailedOperations() throws -> [SyncOperation] {
        let fetchDescriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { operation in
                operation.statusRawValue == "failed"
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try dataController.modelContext.fetch(fetchDescriptor)
    }

    /// Gets operations for a specific entity
    func getOperations(for entityId: String) throws -> [SyncOperation] {
        let fetchDescriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { operation in
                operation.entityId == entityId
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try dataController.modelContext.fetch(fetchDescriptor)
    }

    /// Updates an operation in the queue
    func updateOperation(_ operation: SyncOperation) throws {
        try dataController.save()
    }

    /// Removes an operation from the queue
    func removeOperation(_ operation: SyncOperation) throws {
        dataController.modelContext.delete(operation)
        try dataController.save()
    }

    /// Removes all completed operations
    func clearCompletedOperations() throws {
        let fetchDescriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { operation in
                operation.statusRawValue == "completed"
            }
        )
        let completed = try dataController.modelContext.fetch(fetchDescriptor)
        for operation in completed {
            dataController.modelContext.delete(operation)
        }
        try dataController.save()
    }

    /// Removes all failed operations
    func clearFailedOperations() throws {
        let fetchDescriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { operation in
                operation.statusRawValue == "failed"
            }
        )
        let failed = try dataController.modelContext.fetch(fetchDescriptor)
        for operation in failed {
            dataController.modelContext.delete(operation)
        }
        try dataController.save()
    }

    /// Resets failed operations to pending for retry
    func retryFailedOperations() throws {
        let failed = try getFailedOperations()
        for operation in failed {
            operation.status = .pending
            operation.retryCount = 0
            operation.errorMessage = nil
        }
        try dataController.save()
    }

    /// Gets the total count of pending operations
    func getPendingCount() throws -> Int {
        let pending = try getPendingOperations()
        return pending.count
    }

    /// Checks if there are any pending operations for an entity
    func hasPendingOperations(for entityId: String) throws -> Bool {
        let operations = try getOperations(for: entityId)
        return operations.contains { $0.status == .pending || $0.status == .inProgress }
    }

    /// Cancels all pending operations for an entity (useful when deleting)
    func cancelOperations(for entityId: String) throws {
        let operations = try getOperations(for: entityId)
        for operation in operations where operation.status == .pending {
            dataController.modelContext.delete(operation)
        }
        try dataController.save()
    }
}

// MARK: - Sync Operation Convenience Methods

extension SyncOperation {

    /// Creates and queues a wishlist creation operation
    @MainActor
    static func queueCreateWishlist(
        id: String,
        request: CreateWishlistRequest,
        using queue: OperationQueueManager
    ) throws {
        let operation = SyncOperation.createWishlist(id: id, request: request)
        try queue.addOperation(operation)
    }

    /// Creates and queues a wishlist update operation
    @MainActor
    static func queueUpdateWishlist(
        id: String,
        request: UpdateWishlistRequest,
        using queue: OperationQueueManager
    ) throws {
        // Remove any existing pending update operations for this entity
        let existing = try queue.getOperations(for: id)
        for op in existing where op.operationType == .update && op.status == .pending {
            try queue.removeOperation(op)
        }

        let operation = SyncOperation.updateWishlist(id: id, request: request)
        try queue.addOperation(operation)
    }

    /// Creates and queues a wishlist deletion operation
    @MainActor
    static func queueDeleteWishlist(
        id: String,
        using queue: OperationQueueManager
    ) throws {
        // Cancel any pending operations for this entity
        try queue.cancelOperations(for: id)

        let operation = SyncOperation.deleteWishlist(id: id)
        try queue.addOperation(operation)
    }

    /// Creates and queues an item creation operation
    @MainActor
    static func queueCreateItem(
        id: String,
        wishlistId: String,
        request: AddItemRequest,
        using queue: OperationQueueManager
    ) throws {
        let operation = SyncOperation.createItem(id: id, wishlistId: wishlistId, request: request)
        try queue.addOperation(operation)
    }

    /// Creates and queues an item update operation
    @MainActor
    static func queueUpdateItem(
        id: String,
        wishlistId: String,
        request: UpdateItemRequest,
        using queue: OperationQueueManager
    ) throws {
        // Remove any existing pending update operations for this entity
        let existing = try queue.getOperations(for: id)
        for op in existing where op.operationType == .update && op.status == .pending {
            try queue.removeOperation(op)
        }

        let operation = SyncOperation.updateItem(id: id, wishlistId: wishlistId, request: request)
        try queue.addOperation(operation)
    }

    /// Creates and queues an item deletion operation
    @MainActor
    static func queueDeleteItem(
        id: String,
        wishlistId: String,
        using queue: OperationQueueManager
    ) throws {
        // Cancel any pending operations for this entity
        try queue.cancelOperations(for: id)

        let operation = SyncOperation.deleteItem(id: id, wishlistId: wishlistId)
        try queue.addOperation(operation)
    }
}
