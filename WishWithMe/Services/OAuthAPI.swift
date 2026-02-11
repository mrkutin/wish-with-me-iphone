import Foundation

struct OAuthProvidersResponse: Decodable {
    let providers: [String]
}

struct ConnectedAccount: Decodable, Identifiable {
    let provider: String
    let email: String?
    let connectedAt: String?

    var id: String { provider }

    enum CodingKeys: String, CodingKey {
        case provider
        case email
        case connectedAt = "connected_at"
    }
}

struct ConnectedAccountsResponse: Decodable {
    let accounts: [ConnectedAccount]
    let hasPassword: Bool

    enum CodingKeys: String, CodingKey {
        case accounts
        case hasPassword = "has_password"
    }
}

struct OAuthLinkInitiateResponse: Decodable {
    let authorizationUrl: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case authorizationUrl = "authorization_url"
        case state
    }
}

struct OAuthUnlinkResponse: Decodable {
    let message: String
}

extension APIClient {
    func getOAuthProviders() async throws -> [String] {
        let response: OAuthProvidersResponse = try await request(
            endpoint: "/api/v1/oauth/providers",
            method: "GET",
            requiresAuth: false
        )
        return response.providers
    }

    func getConnectedAccounts() async throws -> ConnectedAccountsResponse {
        return try await request(
            endpoint: "/api/v1/oauth/connected",
            method: "GET"
        )
    }

    func initiateOAuthLink(provider: String) async throws -> OAuthLinkInitiateResponse {
        return try await request(
            endpoint: "/api/v1/oauth/\(provider)/link/initiate",
            method: "POST"
        )
    }

    func unlinkOAuthProvider(provider: String) async throws {
        let _: OAuthUnlinkResponse = try await request(
            endpoint: "/api/v1/oauth/\(provider)/unlink",
            method: "DELETE"
        )
    }

    func getOAuthAuthorizeURL(provider: String) -> URL? {
        var components = URLComponents(string: "\(AppConfig.apiBaseURL)/api/v1/oauth/\(provider)/authorize")
        components?.queryItems = [
            URLQueryItem(name: "callback_url", value: OAuthSessionHelper.callbackURL)
        ]
        return components?.url
    }
}
