import SwiftUI

struct AuthenticationView: View {
    @Environment(\.authManager) private var authManager
    @State private var isShowingLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.appPrimary)

                        Text("WishWithMe")
                            .font(.largeTitle.bold())

                        Text(isShowingLogin
                             ? String(localized: "auth.login.subtitle")
                             : String(localized: "auth.signup.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Form Fields
                    VStack(spacing: 16) {
                        if !isShowingLogin {
                            TextField(String(localized: "auth.field.name"), text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                        }

                        TextField(String(localized: "auth.field.email"), text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        SecureField(String(localized: "auth.field.password"), text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(isShowingLogin ? .password : .newPassword)
                    }
                    .padding(.horizontal, 24)

                    // Password Hint
                    if let hint = passwordHint {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.appError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Primary Button
                    Button {
                        Task {
                            await performAuth()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isShowingLogin
                                     ? String(localized: "auth.button.login")
                                     : String(localized: "auth.button.signup"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.appPrimary : Color.appPrimary.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal, 24)

                    // OAuth Buttons
                    VStack(spacing: 12) {
                        Text(String(localized: "auth.divider.or"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        OAuthButton(
                            title: String(localized: "auth.oauth.google"),
                            icon: "globe",
                            backgroundColor: Color(.systemBackground),
                            foregroundColor: .primary
                        ) {
                            // TODO: Implement Google OAuth
                        }

                        OAuthButton(
                            title: String(localized: "auth.oauth.yandex"),
                            icon: "y.circle.fill",
                            backgroundColor: .yandexYellow,
                            foregroundColor: .black
                        ) {
                            // TODO: Implement Yandex OAuth
                        }
                    }
                    .padding(.horizontal, 24)

                    // Toggle Login/Signup
                    Button {
                        withAnimation {
                            isShowingLogin.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        Text(isShowingLogin
                             ? String(localized: "auth.toggle.signup")
                             : String(localized: "auth.toggle.login"))
                            .font(.footnote)
                            .foregroundStyle(.appPrimary)
                    }
                    .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var isFormValid: Bool {
        if isShowingLogin {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !name.isEmpty && !email.isEmpty && isPasswordValid
        }
    }

    /// Password must be at least 8 characters and contain:
    /// - At least one uppercase letter
    /// - At least one lowercase letter
    /// - At least one digit
    private var isPasswordValid: Bool {
        guard password.count >= 8 else { return false }
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        return hasUppercase && hasLowercase && hasDigit
    }

    private var passwordHint: String? {
        guard !isShowingLogin && !password.isEmpty && !isPasswordValid else { return nil }
        return String(localized: "auth.password.hint")
    }

    private func performAuth() async {
        isLoading = true
        errorMessage = nil

        do {
            if isShowingLogin {
                try await authManager?.login(email: email, password: password)
            } else {
                try await authManager?.signup(name: name, email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - OAuth Button

struct OAuthButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.body.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview("Authentication View") {
    AuthenticationView()
        .withDependencies(DependencyContainer.preview)
}
