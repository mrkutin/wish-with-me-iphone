import Foundation

// MARK: - View State

enum ViewState<T>: Sendable where T: Sendable {
    case idle
    case loading
    case loaded(T)
    case empty
    case error(AppError)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var data: T? {
        if case .loaded(let data) = self {
            return data
        }
        return nil
    }

    var error: AppError? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }

    var isEmpty: Bool {
        if case .empty = self {
            return true
        }
        return false
    }
}

// MARK: - App Error

struct AppError: Error, LocalizedError, Sendable, Identifiable {
    let id: UUID
    let title: String
    let message: String
    let underlyingError: Error?
    let isRetryable: Bool

    var errorDescription: String? {
        message
    }

    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        underlyingError: Error? = nil,
        isRetryable: Bool = false
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.underlyingError = underlyingError
        self.isRetryable = isRetryable
    }

    init(from error: Error) {
        self.id = UUID()

        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                self.title = String(localized: "error.title.unauthorized")
                self.message = String(localized: "error.message.unauthorized")
                self.isRetryable = false
            case .networkError:
                self.title = String(localized: "error.title.network")
                self.message = String(localized: "error.message.network")
                self.isRetryable = true
            case .serverError:
                self.title = String(localized: "error.title.server")
                self.message = String(localized: "error.message.server")
                self.isRetryable = true
            case .validationError(let message):
                self.title = String(localized: "error.title.validation")
                self.message = message
                self.isRetryable = false
            case .clientError(let message):
                self.title = String(localized: "error.title.request")
                self.message = message
                self.isRetryable = false
            default:
                self.title = String(localized: "error.title.unknown")
                self.message = apiError.localizedDescription
                self.isRetryable = apiError.isRetryable
            }
        } else {
            self.title = String(localized: "error.title.unknown")
            self.message = error.localizedDescription
            self.isRetryable = false
        }

        self.underlyingError = error
    }

    // MARK: - Common Errors

    static let offline = AppError(
        title: String(localized: "error.title.offline"),
        message: String(localized: "error.message.offline"),
        isRetryable: true
    )

    static let unknown = AppError(
        title: String(localized: "error.title.unknown"),
        message: String(localized: "error.message.unknown"),
        isRetryable: true
    )
}

// MARK: - Loading State

enum LoadingState: Sendable {
    case idle
    case loading
    case success
    case failure(AppError)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var error: AppError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
