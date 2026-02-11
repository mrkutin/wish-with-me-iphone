import Foundation
import AuthenticationServices
import UIKit

enum OAuthSessionError: Error, LocalizedError {
    case failedToStart
    case cancelled
    case sessionError(Error)

    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Failed to open authentication. Please try again."
        case .cancelled:
            return nil
        case .sessionError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
final class OAuthSessionHelper: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthSessionHelper()

    static let callbackScheme = "wishwithme"
    static let callbackURL = "wishwithme://auth/callback"

    private var activeSession: ASWebAuthenticationSession?
    private var activeContinuation: CheckedContinuation<URL?, any Error>?

    func openSession(url: URL) async throws -> URL? {
        // Cancel any existing session
        activeSession?.cancel()
        activeSession = nil
        activeContinuation = nil

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: OAuthSessionError.failedToStart)
                return
            }

            self.activeContinuation = continuation

            let completionHandler: ASWebAuthenticationSession.CompletionHandler = { [weak self] callbackURL, error in
                guard let self else { return }
                let cont = self.activeContinuation
                self.activeSession = nil
                self.activeContinuation = nil

                guard let cont else { return }

                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    cont.resume(throwing: OAuthSessionError.cancelled)
                    return
                }

                if let error = error {
                    cont.resume(throwing: OAuthSessionError.sessionError(error))
                    return
                }

                cont.resume(returning: callbackURL)
            }

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme,
                completionHandler: completionHandler
            )

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session

            if !session.start() {
                self.activeSession = nil
                self.activeContinuation = nil
                continuation.resume(throwing: OAuthSessionError.failedToStart)
            }
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if Thread.isMainThread {
            return findKeyWindow()
        } else {
            var window: ASPresentationAnchor!
            DispatchQueue.main.sync {
                window = findKeyWindow()
            }
            return window
        }
    }

    private nonisolated func findKeyWindow() -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
