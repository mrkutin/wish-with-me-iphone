import XCTest
@testable import WishWithMe

final class UserModelTests: XCTestCase {
    func testUserDTOEncoding() throws {
        let dto = UserDTO(
            id: "user:test-123",
            rev: "1-abc",
            deleted: nil,
            email: "test@example.com",
            name: "Test User",
            avatarBase64: nil,
            bio: "Test bio",
            publicUrlSlug: "testuser",
            locale: "en",
            birthday: "1990-01-01",
            access: ["user:test-123"],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(dto)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["_id"] as? String, "user:test-123")
        XCTAssertEqual(json?["_rev"] as? String, "1-abc")
        XCTAssertEqual(json?["type"] as? String, "user")
        XCTAssertEqual(json?["email"] as? String, "test@example.com")
        XCTAssertEqual(json?["name"] as? String, "Test User")
        XCTAssertEqual(json?["created_at"] as? String, "2024-01-01T00:00:00Z")
    }

    func testUserDTODecoding() throws {
        let jsonString = """
        {
            "_id": "user:test-123",
            "_rev": "1-abc",
            "type": "user",
            "email": "test@example.com",
            "name": "Test User",
            "locale": "en",
            "access": ["user:test-123"],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let dto = try decoder.decode(UserDTO.self, from: data)

        XCTAssertEqual(dto.id, "user:test-123")
        XCTAssertEqual(dto.rev, "1-abc")
        XCTAssertEqual(dto.type, "user")
        XCTAssertEqual(dto.email, "test@example.com")
        XCTAssertEqual(dto.name, "Test User")
        XCTAssertEqual(dto.locale, "en")
    }

    func testUserModelConversion() throws {
        let dto = UserDTO(
            id: "user:test-123",
            rev: "1-abc",
            deleted: nil,
            email: "test@example.com",
            name: "Test User",
            avatarBase64: nil,
            bio: nil,
            publicUrlSlug: nil,
            locale: "en",
            birthday: nil,
            access: ["user:test-123"],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )

        let user = User(from: dto)

        XCTAssertEqual(user.id, dto.id)
        XCTAssertEqual(user.rev, dto.rev)
        XCTAssertEqual(user.email, dto.email)
        XCTAssertEqual(user.name, dto.name)
        XCTAssertEqual(user.locale, dto.locale)
        XCTAssertFalse(user.isDirty)
        XCTAssertFalse(user.isDeleted)

        let convertedDTO = user.toDTO()
        XCTAssertEqual(convertedDTO.id, dto.id)
        XCTAssertEqual(convertedDTO.email, dto.email)
    }
}
