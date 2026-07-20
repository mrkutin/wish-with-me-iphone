import SwiftUI

struct SocialLoginButtons: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.tertiary)
                Text("or continue with")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                oauthButton(provider: "google", label: "Google", color: Color(red: 0.259, green: 0.522, blue: 0.957), icon: "g.circle.fill")
                oauthButton(provider: "yandex", label: "Yandex", color: Color(red: 0.988, green: 0.247, blue: 0.114), icon: "y.circle.fill")
            }
            .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func oauthButton(provider: String, label: String, color: Color, icon: String) -> some View {
        Button {
            Task { await startOAuth(provider: provider) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel("Sign in with \(label)")
        .disabled(isLoading)
    }

    private func startOAuth(provider: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let authURL = APIClient.shared.getOAuthAuthorizeURL(provider: provider) else {
            errorMessage = String(localized: "Failed to get authorization URL")
            return
        }

        let callbackURL: URL?
        do {
            callbackURL = try await OAuthSessionHelper.shared.openSession(url: authURL)
        } catch OAuthSessionError.cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        guard let url = callbackURL else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = components?.queryItems ?? []

        if let accessToken = params.first(where: { $0.name == "access_token" })?.value,
           let refreshToken = params.first(where: { $0.name == "refresh_token" })?.value {
            do {
                try await authManager.handleOAuthTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
            } catch {
                errorMessage = String(localized: "Failed to complete sign in")
            }
        } else if let error = params.first(where: { $0.name == "error" })?.value {
            if error == "email_exists" {
                let email = params.first(where: { $0.name == "email" })?.value ?? ""
                errorMessage = String(localized: "Email \(email) is already registered. Please sign in with your password.")
            } else {
                errorMessage = error.replacingOccurrences(of: "_", with: " ").capitalized
            }
        } else {
            errorMessage = String(localized: "Authentication failed")
        }
    }

}
