import Foundation
import Observation

struct AuthUserResponse: Codable {
    let id: String
    var email: String
    var name: String
    var avatarBase64: String?
    var bio: String?
    var publicUrlSlug: String?
    var socialLinks: SocialLinksResponse?
    var locale: String
    var birthday: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case avatarBase64 = "avatar_base64"
        case bio
        case publicUrlSlug = "public_url_slug"
        case socialLinks = "social_links"
        case locale
        case birthday
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toUserDTO() -> UserDTO {
        UserDTO(
            id: id,
            rev: nil,
            deleted: nil,
            email: email,
            name: name,
            avatarBase64: avatarBase64,
            bio: bio,
            publicUrlSlug: publicUrlSlug,
            locale: locale,
            birthday: birthday,
            access: [id],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct SocialLinksResponse: Codable {
    var instagram: String?
    var telegram: String?
    var vk: String?
    var twitter: String?
    var facebook: String?
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: AuthUserResponse

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
    let locale: String
}

struct RefreshRequest: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct LogoutRequest: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct EmptyResponse: Codable {}

@MainActor
@Observable
final class AuthManager {
    var isAuthenticated: Bool = false
    var currentUser: UserDTO?
    var isLoading: Bool = false

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        apiClient.setAuthManager(self)
    }

    func loadStoredAuth() async {
        do {
            if let accessToken = try KeychainHelper.read(key: AppConfig.accessTokenKey),
               !accessToken.isEmpty {
                let authUser: AuthUserResponse = try await apiClient.request(
                    endpoint: "/api/v2/auth/me",
                    method: "GET",
                    requiresAuth: true
                )
                currentUser = authUser.toUserDTO()
                isAuthenticated = true
            }
        } catch {
            try? KeychainHelper.delete(key: AppConfig.accessTokenKey)
            try? KeychainHelper.delete(key: AppConfig.refreshTokenKey)
            isAuthenticated = false
            currentUser = nil
        }
    }

    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let request = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await apiClient.request(
            endpoint: "/api/v2/auth/login",
            method: "POST",
            body: request,
            requiresAuth: false
        )

        try KeychainHelper.save(key: AppConfig.accessTokenKey, value: response.accessToken)
        try KeychainHelper.save(key: AppConfig.refreshTokenKey, value: response.refreshToken)

        currentUser = response.user.toUserDTO()
        isAuthenticated = true
    }

    func register(email: String, password: String, name: String, locale: String = "en") async throws {
        isLoading = true
        defer { isLoading = false }

        let request = RegisterRequest(email: email, password: password, name: name, locale: locale)
        let response: AuthResponse = try await apiClient.request(
            endpoint: "/api/v2/auth/register",
            method: "POST",
            body: request,
            requiresAuth: false
        )

        try KeychainHelper.save(key: AppConfig.accessTokenKey, value: response.accessToken)
        try KeychainHelper.save(key: AppConfig.refreshTokenKey, value: response.refreshToken)

        currentUser = response.user.toUserDTO()
        isAuthenticated = true
    }

    func refreshToken() async throws {
        guard let refreshToken = try KeychainHelper.read(key: AppConfig.refreshTokenKey) else {
            throw APIError.unauthorized
        }

        let request = RefreshRequest(refreshToken: refreshToken)
        let response: TokenResponse = try await apiClient.request(
            endpoint: "/api/v2/auth/refresh",
            method: "POST",
            body: request,
            requiresAuth: false
        )

        try KeychainHelper.save(key: AppConfig.accessTokenKey, value: response.accessToken)
        try KeychainHelper.save(key: AppConfig.refreshTokenKey, value: response.refreshToken)
    }

    func handleOAuthTokens(accessToken: String, refreshToken: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try KeychainHelper.save(key: AppConfig.accessTokenKey, value: accessToken)
        try KeychainHelper.save(key: AppConfig.refreshTokenKey, value: refreshToken)

        let authUser: AuthUserResponse = try await apiClient.request(
            endpoint: "/api/v2/auth/me",
            method: "GET",
            requiresAuth: true
        )

        currentUser = authUser.toUserDTO()
        isAuthenticated = true
    }

    func logout() async throws {
        isLoading = true
        defer { isLoading = false }

        if let refreshToken = try? KeychainHelper.read(key: AppConfig.refreshTokenKey) {
            let request = LogoutRequest(refreshToken: refreshToken)
            let _: EmptyResponse? = try? await apiClient.request(
                endpoint: "/api/v2/auth/logout",
                method: "POST",
                body: request,
                requiresAuth: true
            )
        }

        try? KeychainHelper.delete(key: AppConfig.accessTokenKey)
        try? KeychainHelper.delete(key: AppConfig.refreshTokenKey)

        isAuthenticated = false
        currentUser = nil
    }
}
