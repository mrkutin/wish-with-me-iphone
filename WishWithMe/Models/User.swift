import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: String
    var rev: String?
    var email: String
    var name: String
    var avatarBase64: String?
    var bio: String?
    var publicUrlSlug: String?
    var locale: String
    var birthday: String?
    var access: [String]
    var createdAt: String
    var updatedAt: String

    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?

    init(
        id: String,
        rev: String? = nil,
        email: String,
        name: String,
        avatarBase64: String? = nil,
        bio: String? = nil,
        publicUrlSlug: String? = nil,
        locale: String = "en",
        birthday: String? = nil,
        access: [String] = [],
        createdAt: String,
        updatedAt: String,
        isDirty: Bool = false,
        softDeleted: Bool = false,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.rev = rev
        self.email = email
        self.name = name
        self.avatarBase64 = avatarBase64
        self.bio = bio
        self.publicUrlSlug = publicUrlSlug
        self.locale = locale
        self.birthday = birthday
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDirty = isDirty
        self.softDeleted = softDeleted
        self.lastSyncedAt = lastSyncedAt
    }

    convenience init(from dto: UserDTO) {
        self.init(
            id: dto.id,
            rev: dto.rev,
            email: dto.email,
            name: dto.name,
            avatarBase64: dto.avatarBase64,
            bio: dto.bio,
            publicUrlSlug: dto.publicUrlSlug,
            locale: dto.locale,
            birthday: dto.birthday,
            access: dto.access,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func toDTO() -> UserDTO {
        UserDTO(
            id: id,
            rev: rev,
            deleted: softDeleted ? true : nil,
            email: email,
            name: name,
            avatarBase64: avatarBase64,
            bio: bio,
            publicUrlSlug: publicUrlSlug,
            locale: locale,
            birthday: birthday,
            access: access,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct UserDTO: Codable {
    let id: String
    var rev: String?
    var deleted: Bool?
    var type: String = "user"
    let email: String
    var name: String
    var avatarBase64: String?
    var bio: String?
    var publicUrlSlug: String?
    var locale: String
    var birthday: String?
    var access: [String]
    let createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rev = "_rev"
        case deleted = "_deleted"
        case type
        case email
        case name
        case avatarBase64 = "avatar_base64"
        case bio
        case publicUrlSlug = "public_url_slug"
        case locale
        case birthday
        case access
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        rev = try container.decodeIfPresent(String.self, forKey: .rev)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "user"
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        avatarBase64 = try container.decodeIfPresent(String.self, forKey: .avatarBase64)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        publicUrlSlug = try container.decodeIfPresent(String.self, forKey: .publicUrlSlug)
        locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? "en"
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        access = try container.decodeIfPresent([String].self, forKey: .access) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
    }

    init(
        id: String,
        rev: String? = nil,
        deleted: Bool? = nil,
        type: String = "user",
        email: String,
        name: String,
        avatarBase64: String? = nil,
        bio: String? = nil,
        publicUrlSlug: String? = nil,
        locale: String = "en",
        birthday: String? = nil,
        access: [String] = [],
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.rev = rev
        self.deleted = deleted
        self.type = type
        self.email = email
        self.name = name
        self.avatarBase64 = avatarBase64
        self.bio = bio
        self.publicUrlSlug = publicUrlSlug
        self.locale = locale
        self.birthday = birthday
        self.access = access
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
