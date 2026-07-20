import Foundation
import SwiftData

@Model
final class Mark {
    @Attribute(.unique) var id: String
    var rev: String?
    var itemId: String
    var wishlistId: String
    var ownerId: String
    var markedBy: String
    var quantity: Int
    var access: [String]
    var createdAt: String
    var updatedAt: String

    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?

    init(
        id: String,
        rev: String? = nil,
        itemId: String,
        wishlistId: String,
        ownerId: String,
        markedBy: String,
        quantity: Int = 1,
        access: [String] = [],
        createdAt: String,
        updatedAt: String,
        isDirty: Bool = false,
        softDeleted: Bool = false,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.rev = rev
        self.itemId = itemId
        self.wishlistId = wishlistId
        self.ownerId = ownerId
        self.markedBy = markedBy
        self.quantity = quantity
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDirty = isDirty
        self.softDeleted = softDeleted
        self.lastSyncedAt = lastSyncedAt
    }

    convenience init(from dto: MarkDTO) {
        self.init(
            id: dto.id,
            rev: dto.rev,
            itemId: dto.itemId,
            wishlistId: dto.wishlistId,
            ownerId: dto.ownerId,
            markedBy: dto.markedBy,
            quantity: dto.quantity,
            access: dto.access,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func toDTO() -> MarkDTO {
        MarkDTO(
            id: id,
            rev: rev,
            deleted: softDeleted ? true : nil,
            itemId: itemId,
            wishlistId: wishlistId,
            ownerId: ownerId,
            markedBy: markedBy,
            quantity: quantity,
            access: access,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct MarkDTO: Codable {
    let id: String
    var rev: String?
    var deleted: Bool?
    var type: String = "mark"
    let itemId: String
    let wishlistId: String
    let ownerId: String
    let markedBy: String
    var quantity: Int
    var access: [String]
    let createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rev = "_rev"
        case deleted = "_deleted"
        case type
        case itemId = "item_id"
        case wishlistId = "wishlist_id"
        case ownerId = "owner_id"
        case markedBy = "marked_by"
        case quantity
        case access
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        rev = try container.decodeIfPresent(String.self, forKey: .rev)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "mark"
        itemId = try container.decode(String.self, forKey: .itemId)
        wishlistId = try container.decode(String.self, forKey: .wishlistId)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        markedBy = try container.decode(String.self, forKey: .markedBy)
        // Server may store quantity as bool (true=1) due to CouchDB/JSON quirk
        if let intVal = try? container.decode(Int.self, forKey: .quantity) {
            quantity = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .quantity) {
            quantity = boolVal ? 1 : 0
        } else {
            quantity = 1
        }
        access = try container.decodeIfPresent([String].self, forKey: .access) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
    }

    init(
        id: String,
        rev: String? = nil,
        deleted: Bool? = nil,
        itemId: String,
        wishlistId: String,
        ownerId: String,
        markedBy: String,
        quantity: Int = 1,
        access: [String] = [],
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.rev = rev
        self.deleted = deleted
        self.itemId = itemId
        self.wishlistId = wishlistId
        self.ownerId = ownerId
        self.markedBy = markedBy
        self.quantity = quantity
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
