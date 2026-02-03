import Foundation
import SwiftData

// MARK: - Wishlist DTO (API Response)

struct WishlistDTO: Codable, Sendable {
    let id: String
    let userId: String
    let userName: String
    let name: String
    let description: String?
    let dueDate: String?
    let items: [WishlistItemDTO]?
    let sharedWith: [SharedUserDTO]?
    let sharedToken: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case userName
        case name
        case description
        case dueDate
        case items
        case sharedWith
        case sharedToken
        case createdAt
        case updatedAt
    }
}

// MARK: - Shared User DTO

struct SharedUserDTO: Codable, Sendable {
    let userId: String
    let userName: String
    let followedAt: String?
}

// MARK: - Wishlist Requests

struct CreateWishlistRequest: Codable, Sendable {
    let name: String
    let description: String?
    let dueDate: String?
}

struct UpdateWishlistRequest: Codable, Sendable {
    let name: String?
    let description: String?
    let dueDate: String?
}

// MARK: - Shared User Model

struct SharedUser: Codable, Hashable {
    let userId: String
    let userName: String
    let followedAt: Date

    init(userId: String, userName: String, followedAt: Date = Date()) {
        self.userId = userId
        self.userName = userName
        self.followedAt = followedAt
    }

    init(from dto: SharedUserDTO) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        self.userId = dto.userId
        self.userName = dto.userName
        self.followedAt = dto.followedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
    }
}

// MARK: - Wishlist Model (SwiftData)

@Model
final class Wishlist {
    @Attribute(.unique) var id: String
    var userId: String
    var userName: String
    var name: String
    var wishlistDescription: String?
    var dueDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \WishlistItem.wishlist)
    var items: [WishlistItem]
    var sharedWithData: Data?
    var sharedToken: String
    var createdAt: Date
    var updatedAt: Date

    // Sync metadata
    var localVersion: Int
    var serverVersion: Int
    var needsSync: Bool
    var pendingDeletion: Bool

    // Computed property for sharedWith
    var sharedWith: [SharedUser] {
        get {
            guard let data = sharedWithData else { return [] }
            return (try? JSONDecoder().decode([SharedUser].self, from: data)) ?? []
        }
        set {
            sharedWithData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: String,
        userId: String,
        userName: String,
        name: String,
        wishlistDescription: String? = nil,
        dueDate: Date? = nil,
        items: [WishlistItem] = [],
        sharedWith: [SharedUser] = [],
        sharedToken: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        localVersion: Int = 0,
        serverVersion: Int = 0,
        needsSync: Bool = false,
        pendingDeletion: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.name = name
        self.wishlistDescription = wishlistDescription
        self.dueDate = dueDate
        self.items = items
        self.sharedWithData = try? JSONEncoder().encode(sharedWith)
        self.sharedToken = sharedToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.localVersion = localVersion
        self.serverVersion = serverVersion
        self.needsSync = needsSync
        self.pendingDeletion = pendingDeletion
    }

    convenience init(from dto: WishlistDTO) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdAt = dto.createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedAt = dto.updatedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let dueDate = dto.dueDate.flatMap { dateFormatter.date(from: $0) }

        let items = dto.items?.map { WishlistItem(from: $0) } ?? []
        let sharedWith = dto.sharedWith?.map { SharedUser(from: $0) } ?? []

        self.init(
            id: dto.id,
            userId: dto.userId,
            userName: dto.userName,
            name: dto.name,
            wishlistDescription: dto.description,
            dueDate: dueDate,
            items: items,
            sharedWith: sharedWith,
            sharedToken: dto.sharedToken,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
