import SwiftUI

struct AuthenticationView: View {
    @Environment(\.authManager) private var authManager
    @State private var viewModel = AuthViewModel()
    @State private var oAuthHandler: OAuthHandler?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Title
                    headerSection

                    // Form Fields
                    formSection

                    // Validation Hints
                    validationSection

                    // Error Message
                    errorSection

                    // Primary Button
                    submitButton

                    // OAuth Buttons
                    oAuthSection

                    // Toggle Login/Signup
                    toggleModeButton
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                setupDependencies()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "gift.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.appPrimary)

            Text("WishWithMe")
                .font(.largeTitle.bold())

            Text(viewModel.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            if viewModel.mode == .signup {
                TextField(String(localized: "auth.field.name"), text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .accessibilityLabel(String(localized: "auth.field.name"))
            }

            TextField(String(localized: "auth.field.email"), text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .accessibilityLabel(String(localized: "auth.field.email"))

            SecureField(String(localized: "auth.field.password"), text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .textContentType(viewModel.mode == .login ? .password : .newPassword)
                .accessibilityLabel(String(localized: "auth.field.password"))

            // Password Strength Indicator (signup only)
            if viewModel.mode == .signup && !viewModel.password.isEmpty {
                passwordStrengthIndicator
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Password Strength Indicator

    private var passwordStrengthIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(strengthColor(for: index))
                    .frame(height: 4)
            }

            Text(viewModel.passwordStrength.displayName)
                .font(.caption)
                .foregroundStyle(strengthTextColor)
        }
        .animation(.easeInOut, value: viewModel.passwordStrength)
    }

    private func strengthColor(for index: Int) -> Color {
        let strength = viewModel.passwordStrength
        switch strength {
        case .none:
            return Color.secondary.opacity(0.3)
        case .weak:
            return index == 0 ? Color.appError : Color.secondary.opacity(0.3)
        case .medium:
            return index < 2 ? Color.appWarning : Color.secondary.opacity(0.3)
        case .strong:
            return Color.appSuccess
        }
    }

    private var strengthTextColor: Color {
        switch viewModel.passwordStrength {
        case .none: return .secondary
        case .weak: return Color.appError
        case .medium: return Color.appWarning
        case .strong: return Color.appSuccess
        }
    }

    // MARK: - Validation Section

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.mode == .signup {
                if let message = viewModel.nameValidation.message {
                    validationMessage(message)
                }
            }

            if let message = viewModel.emailValidation.message {
                validationMessage(message)
            }

            if viewModel.mode == .signup, let message = viewModel.passwordValidation.message {
                validationMessage(message)
            }
        }
        .padding(.horizontal, 24)
    }

    private func validationMessage(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.error {
            Text(error.message)
                .font(.footnote)
                .foregroundStyle(Color.appError)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .onTapGesture {
                    viewModel.clearError()
                }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task {
                await viewModel.submit()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(viewModel.submitButtonTitle)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isFormValid ? Color.appPrimary : Color.appPrimary.opacity(0.5))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
        .padding(.horizontal, 24)
        .accessibilityLabel(viewModel.submitButtonTitle)
        .accessibilityHint(viewModel.isFormValid ? "" : String(localized: "auth.button.disabled.hint"))
    }

    // MARK: - OAuth Section

    private var oAuthSection: some View {
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
                Task {
                    await viewModel.startOAuth(provider: .google)
                }
            }

            OAuthButton(
                title: String(localized: "auth.oauth.yandex"),
                icon: "y.circle.fill",
                backgroundColor: .yandexYellow,
                foregroundColor: .black
            ) {
                Task {
                    await viewModel.startOAuth(provider: .yandex)
                }
            }

            OAuthButton(
                title: String(localized: "auth.oauth.vk"),
                icon: "v.circle.fill",
                backgroundColor: Color(hex: "#0077FF"),
                foregroundColor: .white
            ) {
                Task {
                    await viewModel.startOAuth(provider: .vk)
                }
            }
        }
        .padding(.horizontal, 24)
        .disabled(viewModel.isLoading)
    }

    // MARK: - Toggle Mode Button

    private var toggleModeButton: some View {
        Button {
            withAnimation {
                viewModel.toggleMode()
            }
        } label: {
            Text(viewModel.toggleModeTitle)
                .font(.footnote)
                .foregroundStyle(Color.appPrimary)
        }
        .padding(.bottom, 32)
        .disabled(viewModel.isLoading)
    }

    // MARK: - Setup

    private func setupDependencies() {
        if let authManager = authManager {
            let handler = OAuthHandler(authManager: authManager)
            oAuthHandler = handler
            viewModel.setDependencies(authManager: authManager, oAuthHandler: handler)
        }
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
        .accessibilityLabel(title)
    }
}

// MARK: - Preview

#Preview("Authentication View") {
    AuthenticationView()
        .withDependencies(DependencyContainer.preview)
}

#Preview("Signup Mode") {
    let view = AuthenticationView()
    return view
        .withDependencies(DependencyContainer.preview)
        .onAppear {
            // Switch to signup mode for preview
        }
}
