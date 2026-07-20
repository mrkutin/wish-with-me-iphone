import Foundation

struct CreateShareRequest: Encodable {
    let linkType: String

    enum CodingKeys: String, CodingKey {
        case linkType = "link_type"
    }
}

struct CreateShareResponse: Decodable {
    let id: String
    let wishlistId: String
    let token: String
    let linkType: String
    let expiresAt: String?
    let accessCount: Int
    let createdAt: String
    let shareUrl: String
    let qrCodeBase64: String?

    enum CodingKeys: String, CodingKey {
        case id
        case wishlistId = "wishlist_id"
        case token
        case linkType = "link_type"
        case expiresAt = "expires_at"
        case accessCount = "access_count"
        case createdAt = "created_at"
        case shareUrl = "share_url"
        case qrCodeBase64 = "qr_code_base64"
    }
}

struct GrantAccessResponse: Decodable {
    let wishlistId: String
    let permissions: [String]

    enum CodingKeys: String, CodingKey {
        case wishlistId = "wishlist_id"
        case permissions
    }
}

extension APIClient {
    func createShareLink(wishlistId: String, linkType: String) async throws -> CreateShareResponse {
        let body = CreateShareRequest(linkType: linkType)
        return try await request(
            endpoint: "/api/v1/wishlists/\(wishlistId)/share",
            method: "POST",
            body: body
        )
    }

    func revokeShareLink(wishlistId: String, shareId: String) async throws {
        try await requestVoid(
            endpoint: "/api/v1/wishlists/\(wishlistId)/share/\(shareId)",
            method: "DELETE"
        )
    }

    func grantAccess(token: String) async throws -> GrantAccessResponse {
        return try await request(
            endpoint: "/api/v1/shared/\(token)/grant-access",
            method: "POST"
        )
    }
}
