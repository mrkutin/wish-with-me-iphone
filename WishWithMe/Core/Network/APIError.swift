import Foundation

// MARK: - API Error

enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case validationError(String)
    case clientError(String)
    case serverError
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
    case noData
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "error.invalidURL")
        case .invalidResponse:
            return String(localized: "error.invalidResponse")
        case .unauthorized:
            return String(localized: "error.unauthorized")
        case .forbidden:
            return String(localized: "error.forbidden")
        case .notFound:
            return String(localized: "error.notFound")
        case .validationError(let message):
            return message
        case .clientError(let message):
            return message
        case .serverError:
            return String(localized: "error.serverError")
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError:
            return String(localized: "error.decodingError")
        case .encodingError:
            return String(localized: "error.encodingError")
        case .noData:
            return String(localized: "error.noData")
        case .unknown:
            return String(localized: "error.unknown")
        }
    }

    var isRetryable: Bool {
        switch self {
        case .serverError, .networkError:
            return true
        default:
            return false
        }
    }
}

// MARK: - API Error Response

struct APIErrorResponse: Codable, Sendable {
    let message: String
    let error: String?
    let statusCode: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle both string and array message formats
        if let messageString = try? container.decode(String.self, forKey: .message) {
            self.message = messageString
        } else if let messageArray = try? container.decode([String].self, forKey: .message) {
            self.message = messageArray.joined(separator: ", ")
        } else {
            self.message = "Unknown error"
        }

        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        self.statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
    }
}

// MARK: - Empty Response

struct EmptyResponse: Codable, Sendable {}
