import Foundation
import Observation
import SwiftData

// MARK: - Sync Status

enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case completed(Date)
    case failed(String)

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}

// MARK: - Sync Engine

@Observable
@MainActor
final class SyncEngine {

    // MARK: - Public State

    private(set) var isSyncing: Bool = false
    private(set) var pendingOperationCount: Int = 0
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?
    private(set) var status: SyncStatus = .idle

    // MARK: - Configuration

    private let maxRetryCount: Int = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0

    // MARK: - Dependencies

    private var apiClient: APIClient?
    private var dataController: DataController?
    private var networkMonitor: NetworkMonitor?
    private var operationQueue: OperationQueueManager?

    // MARK: - Internal State

    private var isMonitoring = false
    private var syncTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {}

    func configure(
        apiClient: APIClient,
        dataController: DataController,
        networkMonitor: NetworkMonitor,
        operationQueue: OperationQueueManager
    ) {
        self.apiClient = apiClient
        self.dataController = dataController
        self.networkMonitor = networkMonitor
        self.operationQueue = operationQueue
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Set up network status change handler
        networkMonitor?.onStatusChange = { [weak self] isConnected in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if isConnected {
                    await self.processPendingOperations()
                }
            }
        }

        // Load initial pending count
        updatePendingCount()

        // If we're online, process any pending operations
        if networkMonitor?.isConnected ?? false {
            Task {
                await processPendingOperations()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        networkMonitor?.onStatusChange = nil
        syncTask?.cancel()
        syncTask = nil
    }

    // MARK: - Queue Operations

    func queueOperation(_ operation: SyncOperation) {
        guard let operationQueue = operationQueue else { return }

        do {
            try operationQueue.addOperation(operation)
            updatePendingCount()

            // If online, process immediately
            if networkMonitor?.isConnected ?? false {
                Task {
                    await processPendingOperations()
                }
            }
        } catch {
            syncError = error
        }
    }

    // MARK: - Process Pending Operations

    func processPendingOperations() async {
        guard !isSyncing else { return }
        guard networkMonitor?.isConnected ?? false else { return }
        guard let operationQueue = operationQueue else { return }

        isSyncing = true
        status = .syncing
        syncError = nil

        defer {
            isSyncing = false
            updatePendingCount()
        }

        do {
            let operations = try operationQueue.getPendingOperations()

            for operation in operations {
                // Check if still connected
                guard networkMonitor?.isConnected ?? false else {
                    status = .idle
                    return
                }

                do {
                    try await executeOperation(operation)
                    try operationQueue.removeOperation(operation)
                } catch {
                    operation.incrementRetry()

                    if operation.canRetry {
                        operation.errorMessage = error.localizedDescription
                        try? operationQueue.updateOperation(operation)

                        // Apply exponential backoff
                        let delay = calculateBackoffDelay(retryCount: operation.retryCount)
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } else {
                        operation.markFailed(with: error.localizedDescription)
                        try? operationQueue.updateOperation(operation)
                    }
                }
            }

            lastSyncDate = Date()
            status = .completed(Date())

        } catch {
            syncError = error
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Full Sync

    func performFullSync() async throws {
        guard networkMonitor?.isConnected ?? false else {
            throw SyncError.offline
        }

        isSyncing = true
        status = .syncing
        syncError = nil

        defer {
            isSyncing = false
            updatePendingCount()
        }

        // Step 1: Process pending local operations
        await processPendingOperations()

        // Step 2: Pull remote changes
        try await pullRemoteChanges()

        // Step 3: Sync items that need sync
        try await syncPendingEntities()

        lastSyncDate = Date()
        status = .completed(Date())
    }

    // MARK: - Private Methods

    private func executeOperation(_ operation: SyncOperation) async throws {
        guard let apiClient = apiClient,
              let dataController = dataController else {
            throw SyncError.notConfigured
        }

        switch operation.entityType {
        case .wishlist:
            try await executeWishlistOperation(operation, apiClient: apiClient, dataController: dataController)
        case .item:
            try await executeItemOperation(operation, apiClient: apiClient, dataController: dataController)
        }
    }

    private func executeWishlistOperation(
        _ operation: SyncOperation,
        apiClient: APIClient,
        dataController: DataController
    ) async throws {
        switch operation.operationType {
        case .create:
            guard let payload = operation.payload,
                  let request = try? JSONDecoder().decode(CreateWishlistRequest.self, from: payload) else {
                throw SyncError.invalidPayload
            }

            let dto = try await apiClient.createWishlist(request)

            // Update local wishlist with server ID
            if let wishlist = try dataController.getWishlist(id: operation.entityId) {
                let oldId = wishlist.id
                wishlist.id = dto.id
                wishlist.sharedToken = dto.sharedToken
                wishlist.needsSync = false
                try dataController.save()
            }

        case .update:
            guard let payload = operation.payload,
                  let request = try? JSONDecoder().decode(UpdateWishlistRequest.self, from: payload) else {
                throw SyncError.invalidPayload
            }

            let _ = try await apiClient.updateWishlist(id: operation.entityId, request: request)

            if let wishlist = try dataController.getWishlist(id: operation.entityId) {
                wishlist.needsSync = false
                try dataController.save()
            }

        case .delete:
            try await apiClient.deleteWishlist(id: operation.entityId)

            if let wishlist = try dataController.getWishlist(id: operation.entityId) {
                try dataController.deleteWishlist(wishlist)
            }
        }
    }

    private func executeItemOperation(
        _ operation: SyncOperation,
        apiClient: APIClient,
        dataController: DataController
    ) async throws {
        guard let wishlistId = operation.parentEntityId else {
            throw SyncError.missingParentId
        }

        switch operation.operationType {
        case .create:
            guard let payload = operation.payload,
                  let request = try? JSONDecoder().decode(AddItemRequest.self, from: payload) else {
                throw SyncError.invalidPayload
            }

            let dto = try await apiClient.addItem(wishlistId: wishlistId, request: request)

            // Update the wishlist with server response
            let _ = try dataController.saveWishlist(dto)

        case .update:
            guard let payload = operation.payload,
                  let request = try? JSONDecoder().decode(UpdateItemRequest.self, from: payload) else {
                throw SyncError.invalidPayload
            }

            let dto = try await apiClient.updateItem(
                wishlistId: wishlistId,
                itemId: operation.entityId,
                request: request
            )

            let _ = try dataController.saveWishlist(dto)

        case .delete:
            try await apiClient.deleteItem(wishlistId: wishlistId, itemId: operation.entityId)

            if let item = try dataController.getItem(id: operation.entityId) {
                try dataController.deleteItem(item)
            }
        }
    }

    private func pullRemoteChanges() async throws {
        guard let apiClient = apiClient,
              let dataController = dataController else {
            throw SyncError.notConfigured
        }

        let remoteWishlists = try await apiClient.getWishlists()

        for dto in remoteWishlists {
            // Check if we have local changes that shouldn't be overwritten
            if let localWishlist = try dataController.getWishlist(id: dto.id) {
                if !localWishlist.needsSync {
                    // Safe to update from server
                    let _ = try dataController.saveWishlist(dto)
                }
            } else {
                // New wishlist from server
                let _ = try dataController.saveWishlist(dto)
            }
        }
    }

    private func syncPendingEntities() async throws {
        guard let apiClient = apiClient,
              let dataController = dataController else {
            throw SyncError.notConfigured
        }

        // Sync wishlists
        let wishlistsNeedingSync = try dataController.getWishlistsNeedingSync()
        for wishlist in wishlistsNeedingSync {
            if wishlist.pendingDeletion {
                try await apiClient.deleteWishlist(id: wishlist.id)
                try dataController.deleteWishlist(wishlist)
            } else {
                let dateFormatter = ISO8601DateFormatter()
                let request = UpdateWishlistRequest(
                    name: wishlist.name,
                    description: wishlist.wishlistDescription,
                    dueDate: wishlist.dueDate.map { dateFormatter.string(from: $0) }
                )

                let _ = try await apiClient.updateWishlist(id: wishlist.id, request: request)
                wishlist.needsSync = false
                try dataController.save()
            }
        }

        // Sync items
        let itemsNeedingSync = try dataController.getItemsNeedingSync()
        for item in itemsNeedingSync {
            guard let wishlist = item.wishlist else { continue }

            if item.pendingDeletion {
                try await apiClient.deleteItem(wishlistId: wishlist.id, itemId: item.id)
                try dataController.deleteItem(item)
            } else {
                let request = UpdateItemRequest(
                    name: item.name,
                    description: item.itemDescription,
                    url: item.url,
                    price: item.price,
                    currency: item.currency,
                    image: item.image,
                    bought: item.bought,
                    priority: item.priority?.rawValue,
                    notes: item.notes
                )

                let _ = try await apiClient.updateItem(
                    wishlistId: wishlist.id,
                    itemId: item.id,
                    request: request
                )
                item.needsSync = false
                try dataController.save()
            }
        }
    }

    private func updatePendingCount() {
        do {
            pendingOperationCount = try operationQueue?.getPendingOperations().count ?? 0
        } catch {
            pendingOperationCount = 0
        }
    }

    private func calculateBackoffDelay(retryCount: Int) -> TimeInterval {
        let delay = baseRetryDelay * pow(2.0, Double(retryCount - 1))
        return min(delay, maxRetryDelay)
    }
}

// MARK: - Sync Error

enum SyncError: LocalizedError {
    case offline
    case notConfigured
    case invalidPayload
    case missingParentId
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            return String(localized: "sync.error.offline")
        case .notConfigured:
            return String(localized: "sync.error.notConfigured")
        case .invalidPayload:
            return String(localized: "sync.error.invalidPayload")
        case .missingParentId:
            return String(localized: "sync.error.missingParentId")
        case .operationFailed(let message):
            return message
        }
    }
}
