import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ShareViewModel {
    var shares: [Share] = []
    var isCreating: Bool = false
    var errorMessage: String?

    private let modelContext: ModelContext
    var syncEngine: SyncEngine?
    private let wishlistId: String

    init(modelContext: ModelContext, syncEngine: SyncEngine?, wishlistId: String) {
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.wishlistId = wishlistId
    }

    func loadShares() {
        let wId = wishlistId
        do {
            let descriptor = FetchDescriptor<Share>(
                predicate: #Predicate<Share> { share in
                    share.wishlistId == wId && share.softDeleted == false && share.revoked == false
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            shares = try modelContext.fetch(descriptor)
        } catch {
            shares = []
        }
    }

    func createShareLink(linkType: String) async {
        isCreating = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.createShareLink(
                wishlistId: wishlistId,
                linkType: linkType
            )
            await syncEngine?.fullSync()
            loadShares()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }

    func revokeShareLink(_ share: Share) async {
        errorMessage = nil

        do {
            try await APIClient.shared.revokeShareLink(
                wishlistId: wishlistId,
                shareId: share.id
            )
            await syncEngine?.fullSync()
            loadShares()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func shareLinkURL(_ share: Share) -> String {
        "https://wishwith.me/s/\(share.token)"
    }
}
