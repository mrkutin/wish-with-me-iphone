import Foundation
import SwiftData

// MARK: - User DTO (API Response)

struct UserDTO: Codable, Sendable {
    let id: String
    let name: String
    let email: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case email
        case createdAt
        case updatedAt
    }
}

// MARK: - Auth Response

struct AuthResponse: Codable, Sendable {
    let token: String
    let user: UserDTO
}

// MARK: - User Model (SwiftData)

@Model
final class User {
    @Attribute(.unique) var id: String
    var name: String
    var email: String
    var createdAt: Date
    var updatedAt: Date

    init(id: String, name: String, email: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(from dto: UserDTO) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdAt = dto.createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedAt = dto.updatedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()

        self.init(
            id: dto.id,
            name: dto.name,
            email: dto.email,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
