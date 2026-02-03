import Foundation

// MARK: - API Client

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private weak var authManager: AuthManager?

    init(
        baseURL: URL = URL(string: "https://api.wishwith.me")!,
        authManager: AuthManager? = nil
    ) {
        self.baseURL = baseURL
        self.authManager = authManager

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let request = try await buildRequest(endpoint, body: body, queryItems: queryItems)
        let (data, response) = try await performRequest(request)

        try validateResponse(response, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func requestVoid(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws {
        let request = try await buildRequest(endpoint, body: body, queryItems: queryItems)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }

    // MARK: - Private Helpers

    private func buildRequest(
        _ endpoint: APIEndpoint,
        body: Encodable?,
        queryItems: [URLQueryItem]?
    ) async throws -> URLRequest {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth token if required
        if endpoint.requiresAuth {
            if let token = await authManager?.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        // Add body
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.encodingError(error)
            }
        }

        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 400, 422:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.validationError(errorResponse.message)
            }
            throw APIError.clientError("Validation failed")
        case 400...499:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.clientError(errorResponse.message)
            }
            throw APIError.clientError("Request failed")
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown
        }
    }

    // MARK: - Auth Convenience Methods

    func login(email: String, password: String) async throws -> AuthResponse {
        struct LoginRequest: Codable {
            let email: String
            let password: String
        }
        return try await request(.login, body: LoginRequest(email: email, password: password))
    }

    func signup(name: String, email: String, password: String) async throws -> AuthResponse {
        struct SignupRequest: Codable {
            let name: String
            let email: String
            let password: String
        }
        return try await request(.signup, body: SignupRequest(name: name, email: email, password: password))
    }

    func logout() async throws {
        try await requestVoid(.logout)
    }

    func getCurrentUser() async throws -> UserDTO {
        return try await request(.me)
    }

    func deleteAccount() async throws {
        try await requestVoid(.deleteAccount)
    }

    // MARK: - Wishlist Convenience Methods

    func getWishlists() async throws -> [WishlistDTO] {
        return try await request(.wishlists)
    }

    func getWishlist(id: String) async throws -> WishlistDTO {
        return try await request(.wishlist(id: id))
    }

    func createWishlist(_ request: CreateWishlistRequest) async throws -> WishlistDTO {
        return try await self.request(.createWishlist, body: request)
    }

    func updateWishlist(id: String, request: UpdateWishlistRequest) async throws -> WishlistDTO {
        return try await self.request(.updateWishlist(id: id), body: request)
    }

    func deleteWishlist(id: String) async throws {
        try await requestVoid(.deleteWishlist(id: id))
    }

    // MARK: - Item Convenience Methods

    func addItem(wishlistId: String, request: AddItemRequest) async throws -> WishlistDTO {
        return try await self.request(.addItem(wishlistId: wishlistId), body: request)
    }

    func updateItem(wishlistId: String, itemId: String, request: UpdateItemRequest) async throws -> WishlistDTO {
        return try await self.request(.updateItem(wishlistId: wishlistId, itemId: itemId), body: request)
    }

    func deleteItem(wishlistId: String, itemId: String) async throws {
        try await requestVoid(.deleteItem(wishlistId: wishlistId, itemId: itemId))
    }

    func resolveItem(url: String) async throws -> ResolveItemResponse {
        return try await request(.resolveItem, body: ResolveItemRequest(url: url))
    }

    // MARK: - Sharing Convenience Methods

    func getWishlistByToken(_ token: String) async throws -> WishlistDTO {
        return try await request(.getByToken(token: token))
    }

    func followWishlist(token: String) async throws -> WishlistDTO {
        return try await request(.follow(token: token))
    }

    func unfollowWishlist(id: String) async throws {
        try await requestVoid(.unfollow(wishlistId: id))
    }

    func getSharedWishlists() async throws -> [WishlistDTO] {
        return try await request(.sharedWishlists)
    }

    // MARK: - Profile Convenience Methods

    func updateProfile(name: String?, email: String?, password: String?) async throws -> UserDTO {
        struct UpdateProfileRequest: Codable {
            let name: String?
            let email: String?
            let password: String?
        }
        return try await request(.updateProfile, body: UpdateProfileRequest(name: name, email: email, password: password))
    }
}
