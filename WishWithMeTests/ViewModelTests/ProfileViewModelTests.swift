import XCTest
@testable import WishWithMe

final class ProfileViewModelTests: XCTestCase {

    // MARK: - Slug Validation

    func testValidSlug() {
        // Valid slugs: lowercase letters, numbers, hyphens
        let validSlugs = ["hello", "my-name", "user123", "test-user-42", "a-b-c"]
        for slug in validSlugs {
            XCTAssertTrue(isValidSlug(slug), "Expected '\(slug)' to be valid")
        }
    }

    func testInvalidSlug() {
        let invalidSlugs = ["Hello", "my name", "user@123", "test_user", "UPPER", "with spaces"]
        for slug in invalidSlugs {
            XCTAssertFalse(isValidSlug(slug), "Expected '\(slug)' to be invalid")
        }
    }

    func testEmptySlugIsValid() {
        // Empty slug is allowed (optional field)
        XCTAssertTrue(isValidSlug(""))
    }

    // MARK: - ConnectedAccount Decoding

    func testConnectedAccountDecoding() throws {
        let json = """
        {
            "provider": "google",
            "email": "user@gmail.com",
            "connected_at": "2024-01-15T10:30:00Z"
        }
        """

        let data = json.data(using: .utf8)!
        let account = try JSONDecoder().decode(ConnectedAccount.self, from: data)

        XCTAssertEqual(account.provider, "google")
        XCTAssertEqual(account.email, "user@gmail.com")
        XCTAssertEqual(account.connectedAt, "2024-01-15T10:30:00Z")
        XCTAssertEqual(account.id, "google")
    }

    func testConnectedAccountDecodingNullEmail() throws {
        let json = """
        {
            "provider": "yandex",
            "email": null,
            "connected_at": null
        }
        """

        let data = json.data(using: .utf8)!
        let account = try JSONDecoder().decode(ConnectedAccount.self, from: data)

        XCTAssertEqual(account.provider, "yandex")
        XCTAssertNil(account.email)
        XCTAssertNil(account.connectedAt)
    }

    // MARK: - ConnectedAccountsResponse Decoding

    func testConnectedAccountsResponseDecoding() throws {
        let json = """
        {
            "accounts": [
                {
                    "provider": "google",
                    "email": "user@gmail.com",
                    "connected_at": "2024-01-15T10:30:00Z"
                }
            ],
            "has_password": true
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConnectedAccountsResponse.self, from: data)

        XCTAssertEqual(response.accounts.count, 1)
        XCTAssertEqual(response.accounts[0].provider, "google")
        XCTAssertTrue(response.hasPassword)
    }

    func testConnectedAccountsResponseNoPassword() throws {
        let json = """
        {
            "accounts": [
                {
                    "provider": "google",
                    "email": "user@gmail.com",
                    "connected_at": "2024-01-15T10:30:00Z"
                },
                {
                    "provider": "yandex",
                    "email": "user@yandex.ru",
                    "connected_at": "2024-02-01T12:00:00Z"
                }
            ],
            "has_password": false
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConnectedAccountsResponse.self, from: data)

        XCTAssertEqual(response.accounts.count, 2)
        XCTAssertFalse(response.hasPassword)
    }

    // MARK: - OAuthLinkInitiateResponse Decoding

    func testOAuthLinkInitiateResponseDecoding() throws {
        let json = """
        {
            "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth?client_id=123",
            "state": "abc123xyz"
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OAuthLinkInitiateResponse.self, from: data)

        XCTAssertEqual(response.authorizationUrl, "https://accounts.google.com/o/oauth2/v2/auth?client_id=123")
        XCTAssertEqual(response.state, "abc123xyz")
    }

    // MARK: - OAuthProvidersResponse Decoding

    func testOAuthProvidersResponseDecoding() throws {
        let json = """
        {
            "providers": ["google", "yandex"]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OAuthProvidersResponse.self, from: data)

        XCTAssertEqual(response.providers, ["google", "yandex"])
    }

    // MARK: - OAuth Authorize URL

    @MainActor
    func testGetOAuthAuthorizeURL() {
        let apiClient = APIClient.shared
        let url = apiClient.getOAuthAuthorizeURL(provider: "google")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("/api/v1/oauth/google/authorize"))
    }

    @MainActor
    func testGetOAuthAuthorizeURLYandex() {
        let apiClient = APIClient.shared
        let url = apiClient.getOAuthAuthorizeURL(provider: "yandex")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("/api/v1/oauth/yandex/authorize"))
    }

    // MARK: - Placeholder Avatar Detection

    func testPlaceholderAvatarDetection() {
        let placeholder = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMTAwIDEwMCI+PGNpcmNsZSBjeD0iNTAiIGN5PSI1MCIgcj0iNTAiIGZpbGw9IiM2MzY2ZjEiLz48dGV4dCB4PSI1MCIgeT0iNTUiIGZvbnQtc2l6ZT0iNDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZpbGw9IndoaXRlIiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiI+PzwvdGV4dD48L3N2Zz4="
        XCTAssertTrue(isPlaceholderAvatar(placeholder))
    }

    func testRealAvatarNotDetectedAsPlaceholder() {
        let realAvatar = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA..."
        XCTAssertFalse(isPlaceholderAvatar(realAvatar))
    }

    func testNilAvatarNotPlaceholder() {
        XCTAssertFalse(isPlaceholderAvatar(""))
    }

    // MARK: - Can Unlink Logic

    func testCanUnlinkWithPassword() {
        // Has password + 1 account = can unlink
        XCTAssertTrue(canUnlink(hasPassword: true, accountCount: 1))
    }

    func testCanUnlinkWithMultipleAccounts() {
        // No password + 2 accounts = can unlink
        XCTAssertTrue(canUnlink(hasPassword: false, accountCount: 2))
    }

    func testCannotUnlinkSingleAccountNoPassword() {
        // No password + 1 account = cannot unlink
        XCTAssertFalse(canUnlink(hasPassword: false, accountCount: 1))
    }

    func testCanUnlinkWithPasswordAndMultipleAccounts() {
        // Has password + 2 accounts = can unlink
        XCTAssertTrue(canUnlink(hasPassword: true, accountCount: 2))
    }

    // MARK: - AuthUserResponse → UserDTO Conversion

    func testAuthUserResponseToUserDTO() throws {
        let json = """
        {
            "id": "user:abc-123",
            "email": "test@example.com",
            "name": "Test User",
            "avatar_base64": "data:image/png;base64,abc",
            "bio": "Hello world",
            "public_url_slug": "testuser",
            "locale": "en",
            "birthday": "1990-05-15",
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-06-15T12:00:00Z"
        }
        """

        let data = json.data(using: .utf8)!
        let authUser = try JSONDecoder().decode(AuthUserResponse.self, from: data)
        let dto = authUser.toUserDTO()

        XCTAssertEqual(dto.id, "user:abc-123")
        XCTAssertEqual(dto.email, "test@example.com")
        XCTAssertEqual(dto.name, "Test User")
        XCTAssertEqual(dto.avatarBase64, "data:image/png;base64,abc")
        XCTAssertEqual(dto.bio, "Hello world")
        XCTAssertEqual(dto.publicUrlSlug, "testuser")
        XCTAssertEqual(dto.locale, "en")
        XCTAssertEqual(dto.birthday, "1990-05-15")
        XCTAssertEqual(dto.access, ["user:abc-123"])
        XCTAssertNil(dto.rev)
    }

    // MARK: - Helpers

    private func isValidSlug(_ slug: String) -> Bool {
        if slug.isEmpty { return true }
        let regex = /^[a-z0-9-]+$/
        return slug.wholeMatch(of: regex) != nil
    }

    private func isPlaceholderAvatar(_ base64: String) -> Bool {
        base64.contains("PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMTAwIDEwMCI")
    }

    private func canUnlink(hasPassword: Bool, accountCount: Int) -> Bool {
        hasPassword || accountCount > 1
    }
}
