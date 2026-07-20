import XCTest
@testable import WishWithMe

final class WishlistModelTests: XCTestCase {
    func testWishlistDTOEncoding() throws {
        let dto = WishlistDTO(
            id: "wishlist:test-123",
            rev: "1-abc",
            deleted: nil,
            ownerId: "user:owner-123",
            name: "Test Wishlist",
            descriptionText: "A test wishlist",
            icon: "card_giftcard",
            isPublic: true,
            access: ["user:owner-123"],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(dto)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["_id"] as? String, "wishlist:test-123")
        XCTAssertEqual(json?["type"] as? String, "wishlist")
        XCTAssertEqual(json?["owner_id"] as? String, "user:owner-123")
        XCTAssertEqual(json?["name"] as? String, "Test Wishlist")
        XCTAssertEqual(json?["is_public"] as? Bool, true)
        XCTAssertEqual(json?["description"] as? String, "A test wishlist")
    }

    func testWishlistDTODecoding() throws {
        let jsonString = """
        {
            "_id": "wishlist:test-123",
            "_rev": "1-abc",
            "type": "wishlist",
            "owner_id": "user:owner-123",
            "name": "Test Wishlist",
            "icon": "card_giftcard",
            "is_public": false,
            "access": ["user:owner-123"],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let dto = try decoder.decode(WishlistDTO.self, from: data)

        XCTAssertEqual(dto.id, "wishlist:test-123")
        XCTAssertEqual(dto.type, "wishlist")
        XCTAssertEqual(dto.ownerId, "user:owner-123")
        XCTAssertEqual(dto.name, "Test Wishlist")
        XCTAssertEqual(dto.icon, "card_giftcard")
        XCTAssertFalse(dto.isPublic)
    }
}
