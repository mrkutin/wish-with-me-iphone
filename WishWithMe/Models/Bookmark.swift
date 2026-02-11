import Foundation
import SwiftData

@Model
final class Bookmark {
    @Attribute(.unique) var id: String
    var rev: String?
    var userId: String
    var shareId: String
    var wishlistId: String?
    var ownerName: String?
    var ownerAvatarBase64: String?
    var wishlistName: String?
    var wishlistIcon: String?
    var wishlistIconColor: String?
    var access: [String]
    var createdAt: String
    var updatedAt: String
    var lastAccessedAt: String

    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?

    init(
        id: String,
        rev: String? = nil,
        userId: String,
        shareId: String,
        wishlistId: String? = nil,
        ownerName: String? = nil,
        ownerAvatarBase64: String? = nil,
        wishlistName: String? = nil,
        wishlistIcon: String? = nil,
        wishlistIconColor: String? = nil,
        access: [String] = [],
        createdAt: String,
        updatedAt: String,
        lastAccessedAt: String,
        isDirty: Bool = false,
        softDeleted: Bool = false,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.rev = rev
        self.userId = userId
        self.shareId = shareId
        self.wishlistId = wishlistId
        self.ownerName = ownerName
        self.ownerAvatarBase64 = ownerAvatarBase64
        self.wishlistName = wishlistName
        self.wishlistIcon = wishlistIcon
        self.wishlistIconColor = wishlistIconColor
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAccessedAt = lastAccessedAt
        self.isDirty = isDirty
        self.softDeleted = softDeleted
        self.lastSyncedAt = lastSyncedAt
    }

    convenience init(from dto: BookmarkDTO) {
        self.init(
            id: dto.id,
            rev: dto.rev,
            userId: dto.userId,
            shareId: dto.shareId,
            wishlistId: dto.wishlistId,
            ownerName: dto.ownerName,
            ownerAvatarBase64: dto.ownerAvatarBase64,
            wishlistName: dto.wishlistName,
            wishlistIcon: dto.wishlistIcon,
            wishlistIconColor: dto.wishlistIconColor,
            access: dto.access,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            lastAccessedAt: dto.lastAccessedAt
        )
    }

    func toDTO() -> BookmarkDTO {
        BookmarkDTO(
            id: id,
            rev: rev,
            deleted: softDeleted ? true : nil,
            userId: userId,
            shareId: shareId,
            wishlistId: wishlistId,
            ownerName: ownerName,
            ownerAvatarBase64: ownerAvatarBase64,
            wishlistName: wishlistName,
            wishlistIcon: wishlistIcon,
            wishlistIconColor: wishlistIconColor,
            access: access,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastAccessedAt: lastAccessedAt
        )
    }
}

struct BookmarkDTO: Codable {
    let id: String
    var rev: String?
    var deleted: Bool?
    var type: String = "bookmark"
    let userId: String
    let shareId: String
    var wishlistId: String?
    var ownerName: String?
    var ownerAvatarBase64: String?
    var wishlistName: String?
    var wishlistIcon: String?
    var wishlistIconColor: String?
    var access: [String]
    let createdAt: String
    var updatedAt: String
    var lastAccessedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rev = "_rev"
        case deleted = "_deleted"
        case type
        case userId = "user_id"
        case shareId = "share_id"
        case wishlistId = "wishlist_id"
        case ownerName = "owner_name"
        case ownerAvatarBase64 = "owner_avatar_base64"
        case wishlistName = "wishlist_name"
        case wishlistIcon = "wishlist_icon"
        case wishlistIconColor = "wishlist_icon_color"
        case access
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastAccessedAt = "last_accessed_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        rev = try container.decodeIfPresent(String.self, forKey: .rev)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "bookmark"
        userId = try container.decode(String.self, forKey: .userId)
        shareId = try container.decode(String.self, forKey: .shareId)
        wishlistId = try container.decodeIfPresent(String.self, forKey: .wishlistId)
        ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName)
        ownerAvatarBase64 = try container.decodeIfPresent(String.self, forKey: .ownerAvatarBase64)
        wishlistName = try container.decodeIfPresent(String.self, forKey: .wishlistName)
        wishlistIcon = try container.decodeIfPresent(String.self, forKey: .wishlistIcon)
        wishlistIconColor = try container.decodeIfPresent(String.self, forKey: .wishlistIconColor)
        access = try container.decodeIfPresent([String].self, forKey: .access) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
        lastAccessedAt = try container.decodeIfPresent(String.self, forKey: .lastAccessedAt) ?? createdAt
    }

    init(
        id: String,
        rev: String? = nil,
        deleted: Bool? = nil,
        type: String = "bookmark",
        userId: String,
        shareId: String,
        wishlistId: String? = nil,
        ownerName: String? = nil,
        ownerAvatarBase64: String? = nil,
        wishlistName: String? = nil,
        wishlistIcon: String? = nil,
        wishlistIconColor: String? = nil,
        access: [String] = [],
        createdAt: String,
        updatedAt: String,
        lastAccessedAt: String
    ) {
        self.id = id
        self.rev = rev
        self.deleted = deleted
        self.type = type
        self.userId = userId
        self.shareId = shareId
        self.wishlistId = wishlistId
        self.ownerName = ownerName
        self.ownerAvatarBase64 = ownerAvatarBase64
        self.wishlistName = wishlistName
        self.wishlistIcon = wishlistIcon
        self.wishlistIconColor = wishlistIconColor
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAccessedAt = lastAccessedAt
    }
}
