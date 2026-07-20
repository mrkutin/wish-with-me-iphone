import Foundation
import SwiftData

@Model
final class Share {
    @Attribute(.unique) var id: String
    var rev: String?
    var wishlistId: String
    var ownerId: String
    var token: String
    var linkType: String
    var expiresAt: String?
    var accessCount: Int
    var revoked: Bool
    var grantedUsers: [String]
    var access: [String]
    var createdAt: String
    var updatedAt: String
    var qrCodeBase64: String?

    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?

    init(
        id: String,
        rev: String? = nil,
        wishlistId: String,
        ownerId: String,
        token: String,
        linkType: String,
        expiresAt: String? = nil,
        accessCount: Int = 0,
        revoked: Bool = false,
        grantedUsers: [String] = [],
        access: [String] = [],
        createdAt: String,
        updatedAt: String,
        qrCodeBase64: String? = nil,
        isDirty: Bool = false,
        softDeleted: Bool = false,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.rev = rev
        self.wishlistId = wishlistId
        self.ownerId = ownerId
        self.token = token
        self.linkType = linkType
        self.expiresAt = expiresAt
        self.accessCount = accessCount
        self.revoked = revoked
        self.grantedUsers = grantedUsers
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.qrCodeBase64 = qrCodeBase64
        self.isDirty = isDirty
        self.softDeleted = softDeleted
        self.lastSyncedAt = lastSyncedAt
    }

    convenience init(from dto: ShareDTO) {
        self.init(
            id: dto.id,
            rev: dto.rev,
            wishlistId: dto.wishlistId,
            ownerId: dto.ownerId,
            token: dto.token,
            linkType: dto.linkType,
            expiresAt: dto.expiresAt,
            accessCount: dto.accessCount,
            revoked: dto.revoked,
            grantedUsers: dto.grantedUsers,
            access: dto.access,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt ?? dto.createdAt,
            qrCodeBase64: dto.qrCodeBase64
        )
    }

    func toDTO() -> ShareDTO {
        ShareDTO(
            id: id,
            rev: rev,
            deleted: softDeleted ? true : nil,
            wishlistId: wishlistId,
            ownerId: ownerId,
            token: token,
            linkType: linkType,
            expiresAt: expiresAt,
            accessCount: accessCount,
            revoked: revoked,
            grantedUsers: grantedUsers,
            access: access,
            createdAt: createdAt,
            updatedAt: updatedAt,
            qrCodeBase64: qrCodeBase64
        )
    }
}

struct ShareDTO: Codable {
    let id: String
    var rev: String?
    var deleted: Bool?
    var type: String = "share"
    let wishlistId: String
    let ownerId: String
    var token: String
    var linkType: String
    var expiresAt: String?
    var accessCount: Int
    var revoked: Bool
    var grantedUsers: [String]
    var access: [String]
    let createdAt: String
    var updatedAt: String?
    var qrCodeBase64: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rev = "_rev"
        case deleted = "_deleted"
        case type
        case wishlistId = "wishlist_id"
        case ownerId = "owner_id"
        case token
        case linkType = "link_type"
        case expiresAt = "expires_at"
        case accessCount = "access_count"
        case revoked
        case grantedUsers = "granted_users"
        case access
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case qrCodeBase64 = "qr_code_base64"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        rev = try container.decodeIfPresent(String.self, forKey: .rev)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "share"
        wishlistId = try container.decode(String.self, forKey: .wishlistId)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        token = try container.decode(String.self, forKey: .token)
        linkType = try container.decode(String.self, forKey: .linkType)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        accessCount = try container.decodeIfPresent(Int.self, forKey: .accessCount) ?? 0
        revoked = try container.decodeIfPresent(Bool.self, forKey: .revoked) ?? false
        grantedUsers = try container.decodeIfPresent([String].self, forKey: .grantedUsers) ?? []
        access = try container.decodeIfPresent([String].self, forKey: .access) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        qrCodeBase64 = try container.decodeIfPresent(String.self, forKey: .qrCodeBase64)
    }

    init(
        id: String,
        rev: String? = nil,
        deleted: Bool? = nil,
        type: String = "share",
        wishlistId: String,
        ownerId: String,
        token: String,
        linkType: String,
        expiresAt: String? = nil,
        accessCount: Int = 0,
        revoked: Bool = false,
        grantedUsers: [String] = [],
        access: [String] = [],
        createdAt: String,
        updatedAt: String? = nil,
        qrCodeBase64: String? = nil
    ) {
        self.id = id
        self.rev = rev
        self.deleted = deleted
        self.type = type
        self.wishlistId = wishlistId
        self.ownerId = ownerId
        self.token = token
        self.linkType = linkType
        self.expiresAt = expiresAt
        self.accessCount = accessCount
        self.revoked = revoked
        self.grantedUsers = grantedUsers
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.qrCodeBase64 = qrCodeBase64
    }
}
