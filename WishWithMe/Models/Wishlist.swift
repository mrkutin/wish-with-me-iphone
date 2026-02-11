import Foundation
import SwiftData

@Model
final class Wishlist {
    @Attribute(.unique) var id: String
    var rev: String?
    var ownerId: String
    var name: String
    var descriptionText: String?
    var icon: String
    var iconColor: String?
    var isPublic: Bool
    var access: [String]
    var createdAt: String
    var updatedAt: String

    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?

    init(
        id: String,
        rev: String? = nil,
        ownerId: String,
        name: String,
        descriptionText: String? = nil,
        icon: String = "card_giftcard",
        iconColor: String? = nil,
        isPublic: Bool = false,
        access: [String] = [],
        createdAt: String,
        updatedAt: String,
        isDirty: Bool = false,
        softDeleted: Bool = false,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.rev = rev
        self.ownerId = ownerId
        self.name = name
        self.descriptionText = descriptionText
        self.icon = icon
        self.iconColor = iconColor
        self.isPublic = isPublic
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDirty = isDirty
        self.softDeleted = softDeleted
        self.lastSyncedAt = lastSyncedAt
    }

    convenience init(from dto: WishlistDTO) {
        self.init(
            id: dto.id,
            rev: dto.rev,
            ownerId: dto.ownerId,
            name: dto.name,
            descriptionText: dto.descriptionText,
            icon: dto.icon ?? "card_giftcard",
            iconColor: dto.iconColor,
            isPublic: dto.isPublic,
            access: dto.access,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func toDTO() -> WishlistDTO {
        WishlistDTO(
            id: id,
            rev: rev,
            deleted: softDeleted ? true : nil,
            ownerId: ownerId,
            name: name,
            descriptionText: descriptionText,
            icon: icon.isEmpty ? nil : icon,
            iconColor: iconColor,
            isPublic: isPublic,
            access: access,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct WishlistDTO: Codable {
    let id: String
    var rev: String?
    var deleted: Bool?
    var type: String = "wishlist"
    let ownerId: String
    var name: String
    var descriptionText: String?
    var icon: String?
    var iconColor: String?
    var isPublic: Bool
    var access: [String]
    let createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rev = "_rev"
        case deleted = "_deleted"
        case type
        case ownerId = "owner_id"
        case name
        case descriptionText = "description"
        case icon
        case iconColor = "icon_color"
        case isPublic = "is_public"
        case access
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        rev = try container.decodeIfPresent(String.self, forKey: .rev)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "wishlist"
        ownerId = try container.decode(String.self, forKey: .ownerId)
        name = try container.decode(String.self, forKey: .name)
        descriptionText = try container.decodeIfPresent(String.self, forKey: .descriptionText)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        iconColor = try container.decodeIfPresent(String.self, forKey: .iconColor)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        access = try container.decodeIfPresent([String].self, forKey: .access) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
    }

    init(
        id: String,
        rev: String? = nil,
        deleted: Bool? = nil,
        type: String = "wishlist",
        ownerId: String,
        name: String,
        descriptionText: String? = nil,
        icon: String? = nil,
        iconColor: String? = nil,
        isPublic: Bool = false,
        access: [String] = [],
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.rev = rev
        self.deleted = deleted
        self.type = type
        self.ownerId = ownerId
        self.name = name
        self.descriptionText = descriptionText
        self.icon = icon
        self.iconColor = iconColor
        self.isPublic = isPublic
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
