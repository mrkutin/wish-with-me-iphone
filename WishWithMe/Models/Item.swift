import Foundation
import SwiftData

@Model
final class Item {
    @Attribute(.unique) var id: String
    var rev: String?
    var wishlistId: String
    var ownerId: String
    var title: String
    var descriptionText: String?
    var price: Double?
    var currency: String?
    var quantity: Int
    var sourceUrl: String?
    var imageUrl: String?
    var imageBase64: String?
    var status: String
    var resolveConfidence: Double?
    var resolveError: String?
    var resolvedAt: String?
    var access: [String]
    var createdAt: String
    var updatedAt: String

    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?

    init(
        id: String,
        rev: String? = nil,
        wishlistId: String,
        ownerId: String,
        title: String,
        descriptionText: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        quantity: Int = 1,
        sourceUrl: String? = nil,
        imageUrl: String? = nil,
        imageBase64: String? = nil,
        status: String = "pending",
        resolveConfidence: Double? = nil,
        resolveError: String? = nil,
        resolvedAt: String? = nil,
        access: [String] = [],
        createdAt: String,
        updatedAt: String,
        isDirty: Bool = false,
        softDeleted: Bool = false,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.rev = rev
        self.wishlistId = wishlistId
        self.ownerId = ownerId
        self.title = title
        self.descriptionText = descriptionText
        self.price = price
        self.currency = currency
        self.quantity = quantity
        self.sourceUrl = sourceUrl
        self.imageUrl = imageUrl
        self.imageBase64 = imageBase64
        self.status = status
        self.resolveConfidence = resolveConfidence
        self.resolveError = resolveError
        self.resolvedAt = resolvedAt
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDirty = isDirty
        self.softDeleted = softDeleted
        self.lastSyncedAt = lastSyncedAt
    }

    convenience init(from dto: ItemDTO) {
        self.init(
            id: dto.id,
            rev: dto.rev,
            wishlistId: dto.wishlistId,
            ownerId: dto.ownerId,
            title: dto.title,
            descriptionText: dto.descriptionText,
            price: dto.price,
            currency: dto.currency,
            quantity: dto.quantity,
            sourceUrl: dto.sourceUrl,
            imageUrl: dto.imageUrl,
            imageBase64: dto.imageBase64,
            status: dto.status,
            resolveConfidence: dto.resolveConfidence,
            resolveError: dto.resolveError,
            resolvedAt: dto.resolvedAt,
            access: dto.access,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func toDTO() -> ItemDTO {
        ItemDTO(
            id: id,
            rev: rev,
            deleted: softDeleted ? true : nil,
            wishlistId: wishlistId,
            ownerId: ownerId,
            title: title,
            descriptionText: descriptionText,
            price: price,
            currency: currency,
            quantity: quantity,
            sourceUrl: sourceUrl,
            imageUrl: imageUrl,
            imageBase64: imageBase64,
            status: status,
            resolveConfidence: resolveConfidence,
            resolveError: resolveError,
            resolvedAt: resolvedAt,
            access: access,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct ItemDTO: Codable {
    let id: String
    var rev: String?
    var deleted: Bool?
    var type: String = "item"
    let wishlistId: String
    let ownerId: String
    var title: String
    var descriptionText: String?
    var price: Double?
    var currency: String?
    var quantity: Int
    var sourceUrl: String?
    var imageUrl: String?
    var imageBase64: String?
    var status: String
    var resolveConfidence: Double?
    var resolveError: String?
    var resolvedAt: String?
    var access: [String]
    let createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rev = "_rev"
        case deleted = "_deleted"
        case type
        case wishlistId = "wishlist_id"
        case ownerId = "owner_id"
        case title
        case descriptionText = "description"
        case price
        case currency
        case quantity
        case sourceUrl = "source_url"
        case imageUrl = "image_url"
        case imageBase64 = "image_base64"
        case status
        case resolveConfidence = "resolve_confidence"
        case resolveError = "resolve_error"
        case resolvedAt = "resolved_at"
        case access
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        rev = try container.decodeIfPresent(String.self, forKey: .rev)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "item"
        wishlistId = try container.decode(String.self, forKey: .wishlistId)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        title = try container.decode(String.self, forKey: .title)
        descriptionText = try container.decodeIfPresent(String.self, forKey: .descriptionText)
        price = try container.decodeIfPresent(Double.self, forKey: .price)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)

        // Server may return quantity as Bool (true/false) or Int
        if let intVal = try? container.decode(Int.self, forKey: .quantity) {
            quantity = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .quantity) {
            quantity = boolVal ? 1 : 0
        } else {
            quantity = 1
        }

        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        resolveConfidence = try container.decodeIfPresent(Double.self, forKey: .resolveConfidence)
        resolveError = try container.decodeIfPresent(String.self, forKey: .resolveError)
        resolvedAt = try container.decodeIfPresent(String.self, forKey: .resolvedAt)
        access = try container.decodeIfPresent([String].self, forKey: .access) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
    }

    init(
        id: String,
        rev: String? = nil,
        deleted: Bool? = nil,
        type: String = "item",
        wishlistId: String,
        ownerId: String,
        title: String,
        descriptionText: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        quantity: Int = 1,
        sourceUrl: String? = nil,
        imageUrl: String? = nil,
        imageBase64: String? = nil,
        status: String = "pending",
        resolveConfidence: Double? = nil,
        resolveError: String? = nil,
        resolvedAt: String? = nil,
        access: [String] = [],
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.rev = rev
        self.deleted = deleted
        self.type = type
        self.wishlistId = wishlistId
        self.ownerId = ownerId
        self.title = title
        self.descriptionText = descriptionText
        self.price = price
        self.currency = currency
        self.quantity = quantity
        self.sourceUrl = sourceUrl
        self.imageUrl = imageUrl
        self.imageBase64 = imageBase64
        self.status = status
        self.resolveConfidence = resolveConfidence
        self.resolveError = resolveError
        self.resolvedAt = resolvedAt
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
