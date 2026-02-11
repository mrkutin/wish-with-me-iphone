import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case invalidURLForItem
    case serverError
    case decodingError(Error)
    case networkError(Error)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Conflict with existing data"
        case .invalidURLForItem:
            return "Invalid URL for item"
        case .serverError:
            return "Server error. Please try again later."
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let message):
            return message
        }
    }
}

struct APIErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let code: String
        let message: String
        let details: [String: String]?
    }
}

@MainActor
final class APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private var authManager: AuthManager?

    private init() {
        self.baseURL = AppConfig.apiBaseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.requestTimeout
        self.session = URLSession(configuration: config)
    }

    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        return try await performRequest(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth, isRetry: false)
    }

    func requestVoid(
        endpoint: String,
        method: String = "DELETE",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws {
        let _: Data = try await performRawRequest(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth, isRetry: false)
    }

    private func performRawRequest(
        endpoint: String,
        method: String,
        body: Encodable?,
        requiresAuth: Bool,
        isRetry: Bool
    ) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            if let token = try? KeychainHelper.read(key: AppConfig.accessTokenKey) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                if !isRetry, let authManager = authManager {
                    try await authManager.refreshToken()
                    return try await performRawRequest(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth, isRetry: true)
                }
                throw APIError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw mapError(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: Encodable?,
        requiresAuth: Bool,
        isRetry: Bool
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            if let token = try? KeychainHelper.read(key: AppConfig.accessTokenKey) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                if !isRetry, let authManager = authManager {
                    try await authManager.refreshToken()
                    return try await performRequest(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth, isRetry: true)
                }
                throw APIError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw mapError(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            let decoder = JSONDecoder()
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func mapError(statusCode: Int, errorResponse: APIErrorResponse?) -> APIError {
        if let errorResponse = errorResponse {
            switch errorResponse.error.code {
            case "UNAUTHORIZED":
                return .unauthorized
            case "FORBIDDEN":
                return .forbidden
            case "NOT_FOUND":
                return .notFound
            case "CONFLICT":
                return .conflict
            case "INVALID_URL":
                return .invalidURLForItem
            default:
                return .unknown(errorResponse.error.message)
            }
        }

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 409:
            return .conflict
        case 422:
            return .invalidURLForItem
        case 500...599:
            return .serverError
        default:
            return .unknown("HTTP \(statusCode)")
        }
    }
}
