import XCTest
@testable import WishWithMe

final class IDGeneratorTests: XCTestCase {
    func testCreateID() {
        let userID = IDGenerator.create(type: "user")
        XCTAssertTrue(userID.hasPrefix("user:"))

        let parts = userID.split(separator: ":")
        XCTAssertEqual(parts.count, 2)

        let uuidString = String(parts[1])
        let uuid = UUID(uuidString: uuidString)
        XCTAssertNotNil(uuid, "Generated UUID should be valid")
        XCTAssertEqual(uuidString, uuidString.lowercased(), "UUID should be lowercase")
    }

    func testExtractUUID() {
        let fullID = "wishlist:abc-123-def-456"
        let extracted = IDGenerator.extractUUID(fullID)
        XCTAssertEqual(extracted, "abc-123-def-456")

        let noPrefix = "just-a-string"
        let extractedNoPrefix = IDGenerator.extractUUID(noPrefix)
        XCTAssertEqual(extractedNoPrefix, noPrefix)
    }

    func testExtractType() {
        let fullID = "item:abc-123"
        let type = IDGenerator.extractType(fullID)
        XCTAssertEqual(type, "item")

        let noPrefix = "just-a-string"
        let extractedType = IDGenerator.extractType(noPrefix)
        XCTAssertNil(extractedType)
    }

    func testDifferentTypes() {
        let types = ["user", "wishlist", "item", "mark", "share", "bookmark"]

        for type in types {
            let id = IDGenerator.create(type: type)
            XCTAssertTrue(id.hasPrefix("\(type):"))

            let extractedType = IDGenerator.extractType(id)
            XCTAssertEqual(extractedType, type)
        }
    }
}
