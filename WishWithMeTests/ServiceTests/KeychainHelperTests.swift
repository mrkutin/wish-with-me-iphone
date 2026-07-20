import XCTest
@testable import WishWithMe

final class KeychainHelperTests: XCTestCase {
    let testKey = "test_token"

    override func tearDown() {
        try? KeychainHelper.delete(key: testKey)
        super.tearDown()
    }

    func testSaveAndRead() throws {
        let testValue = "test-token-value-123"

        try KeychainHelper.save(key: testKey, value: testValue)

        let retrievedValue = try KeychainHelper.read(key: testKey)
        XCTAssertEqual(retrievedValue, testValue)
    }

    func testUpdate() throws {
        let initialValue = "initial-value"
        let updatedValue = "updated-value"

        try KeychainHelper.save(key: testKey, value: initialValue)
        let firstRead = try KeychainHelper.read(key: testKey)
        XCTAssertEqual(firstRead, initialValue)

        try KeychainHelper.save(key: testKey, value: updatedValue)
        let secondRead = try KeychainHelper.read(key: testKey)
        XCTAssertEqual(secondRead, updatedValue)
    }

    func testDelete() throws {
        let testValue = "test-value"

        try KeychainHelper.save(key: testKey, value: testValue)
        XCTAssertNotNil(try KeychainHelper.read(key: testKey))

        try KeychainHelper.delete(key: testKey)
        let retrievedValue = try KeychainHelper.read(key: testKey)
        XCTAssertNil(retrievedValue)
    }

    func testReadNonExistentKey() throws {
        let retrievedValue = try KeychainHelper.read(key: "non-existent-key-xyz")
        XCTAssertNil(retrievedValue)
    }
}
