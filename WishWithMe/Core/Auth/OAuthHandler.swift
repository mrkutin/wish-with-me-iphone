import Foundation
import AuthenticationServices

// MARK: - OAuth Error

enum OAuthError: Error, LocalizedError, Sendable {
    case invalidProvider
    case authenticationFailed
    case callbackURLMissing
    case tokenExtractionFailed
    case userCancelled
    case presentationContextMissing
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidProvider:
            return String(localized: "oauth.error.invalidProvider")
        case .authenticationFailed:
            return String(localized: "oauth.error.authenticationFailed")
        case .callbackURLMissing:
            return String(localized: "oauth.error.callbackURLMissing")
        case .tokenExtractionFailed:
            return String(localized: "oauth.error.tokenExtractionFailed")
        case .userCancelled:
            return String(localized: "oauth.error.userCancelled")
        case .presentationContextMissing:
            return String(localized: "oauth.error.presentationContextMissing")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - OAuth Handler

@MainActor
final class OAuthHandler: NSObject {

    // MARK: - Properties

    private weak var authManager: AuthManager?
    private var authSession: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<String, Error>?

    private let baseURL = "https://api.wishwith.me"
    private let callbackURLScheme = "wishwithme"

    // MARK: - Initialization

    init(authManager: AuthManager) {
        self.authManager = authManager
        super.init()
    }

    // MARK: - Public Methods

    /// Starts OAuth flow for the specified provider
    /// - Parameter provider: The OAuth provider (Google, Yandex, VK)
    func startOAuth(provider: OAuthProvider) async throws {
        guard let authURL = buildAuthURL(for: provider) else {
            throw OAuthError.invalidProvider
        }

        let token = try await performOAuth(authURL: authURL)
        try await authManager?.handleOAuthToken(token)
    }

    /// Handles OAuth callback URL (for Universal Links / Deep Links)
    /// - Parameter url: The callback URL with token
    func handleCallback(url: URL) async throws {
        guard let token = extractToken(from: url) else {
            throw OAuthError.tokenExtractionFailed
        }

        try await authManager?.handleOAuthToken(token)
    }

    /// Checks if a URL is a valid OAuth callback
    /// - Parameter url: The URL to check
    /// - Returns: True if the URL is a valid OAuth callback
    func isOAuthCallback(_ url: URL) -> Bool {
        // Check custom URL scheme
        if url.scheme == callbackURLScheme && url.host == "oauth" {
            return true
        }

        // Check universal link
        if (url.host == "wishwith.me" || url.host == "api.wishwith.me") &&
           url.pathComponents.contains("callback") {
            return true
        }

        return false
    }

    // MARK: - Private Methods

    private func buildAuthURL(for provider: OAuthProvider) -> URL? {
        var components = URLComponents(string: baseURL)

        switch provider {
        case .google:
            components?.path = "/auth/google"
        case .yandex:
            components?.path = "/auth/yandex"
        case .vk:
            components?.path = "/auth/vk"
        }

        // Add redirect URI for mobile app
        components?.queryItems = [
            URLQueryItem(name: "redirect_uri", value: "\(callbackURLScheme)://oauth/callback"),
            URLQueryItem(name: "platform", value: "ios")
        ]

        return components?.url
    }

    private func performOAuth(authURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }

                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: OAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: OAuthError.unknown(error))
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuthError.callbackURLMissing)
                    return
                }

                guard let token = self.extractToken(from: callbackURL) else {
                    continuation.resume(throwing: OAuthError.tokenExtractionFailed)
                    return
                }

                continuation.resume(returning: token)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            self.authSession = session

            if !session.start() {
                continuation.resume(throwing: OAuthError.authenticationFailed)
            }
        }
    }

    /// Extracts the token from the callback URL
    /// Supports multiple URL formats:
    /// - wishwithme://oauth/callback?token=xxx
    /// - wishwithme://oauth/callback#token=xxx
    /// - https://wishwith.me/auth/callback?token=xxx
    private func extractToken(from url: URL) -> String? {
        // Try query parameter first
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Check query items
            if let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
                return token
            }

            // Check for error
            if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                print("OAuth error: \(error)")
                return nil
            }
        }

        // Try fragment (hash) parameters
        if let fragment = url.fragment {
            let params = fragment.components(separatedBy: "&")
            for param in params {
                let parts = param.components(separatedBy: "=")
                if parts.count == 2 && parts[0] == "token" {
                    return parts[1]
                }
            }
        }

        // Try path components (for some OAuth flows)
        let pathComponents = url.pathComponents
        if let tokenIndex = pathComponents.firstIndex(of: "token"),
           tokenIndex + 1 < pathComponents.count {
            return pathComponents[tokenIndex + 1]
        }

        return nil
    }

    /// Cancels any ongoing OAuth session
    func cancelOAuth() {
        authSession?.cancel()
        authSession = nil
        continuation?.resume(throwing: OAuthError.userCancelled)
        continuation = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthHandler: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the key window from the connected scenes
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            // Fallback to first available window
            return UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first ?? ASPresentationAnchor()
        }
        return window
    }
}
