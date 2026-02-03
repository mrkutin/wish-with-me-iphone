import Foundation
import Observation

// MARK: - OAuth Provider

enum OAuthProvider: String, CaseIterable, Sendable {
    case google
    case yandex
    case vk

    var displayName: String {
        switch self {
        case .google: return "Google"
        case .yandex: return "Yandex"
        case .vk: return "VK"
        }
    }

    var iconName: String {
        switch self {
        case .google: return "globe"
        case .yandex: return "y.circle.fill"
        case .vk: return "v.circle.fill"
        }
    }

    var authURL: String {
        switch self {
        case .google: return "https://api.wishwith.me/auth/google"
        case .yandex: return "https://api.wishwith.me/auth/yandex"
        case .vk: return "https://api.wishwith.me/auth/vk"
        }
    }
}

// MARK: - Auth Mode

enum AuthMode: Sendable {
    case login
    case signup
}

// MARK: - Validation Result

struct ValidationResult: Sendable {
    let isValid: Bool
    let message: String?

    static let valid = ValidationResult(isValid: true, message: nil)

    static func invalid(_ message: String) -> ValidationResult {
        ValidationResult(isValid: false, message: message)
    }
}

// MARK: - Auth View Model

@Observable
@MainActor
final class AuthViewModel {

    // MARK: - Dependencies

    private var authManager: AuthManager?
    private var oAuthHandler: OAuthHandler?

    // MARK: - Form State

    var email: String = ""
    var password: String = ""
    var name: String = ""
    var confirmPassword: String = ""

    // MARK: - UI State

    var mode: AuthMode = .login
    private(set) var isLoading: Bool = false
    private(set) var error: AppError?
    private(set) var showOAuthSheet: Bool = false
    private(set) var oAuthURL: URL?

    // MARK: - Validation State

    var emailValidation: ValidationResult {
        guard !email.isEmpty else {
            return .valid // Don't show error for empty field
        }
        return validateEmail(email)
    }

    var passwordValidation: ValidationResult {
        guard !password.isEmpty else {
            return .valid // Don't show error for empty field
        }

        if mode == .login {
            return .valid // No strict validation for login
        }

        return validatePassword(password)
    }

    var nameValidation: ValidationResult {
        guard mode == .signup else {
            return .valid
        }
        guard !name.isEmpty else {
            return .valid // Don't show error for empty field
        }
        return validateName(name)
    }

    var isFormValid: Bool {
        switch mode {
        case .login:
            return !email.isEmpty && !password.isEmpty && validateEmail(email).isValid
        case .signup:
            return !name.isEmpty &&
                   !email.isEmpty &&
                   !password.isEmpty &&
                   validateName(name).isValid &&
                   validateEmail(email).isValid &&
                   validatePassword(password).isValid
        }
    }

    // MARK: - Computed Properties

    var submitButtonTitle: String {
        switch mode {
        case .login:
            return String(localized: "auth.button.login")
        case .signup:
            return String(localized: "auth.button.signup")
        }
    }

    var toggleModeTitle: String {
        switch mode {
        case .login:
            return String(localized: "auth.toggle.signup")
        case .signup:
            return String(localized: "auth.toggle.login")
        }
    }

    var subtitle: String {
        switch mode {
        case .login:
            return String(localized: "auth.login.subtitle")
        case .signup:
            return String(localized: "auth.signup.subtitle")
        }
    }

    // MARK: - Initialization

    init(authManager: AuthManager? = nil) {
        self.authManager = authManager
    }

    func setDependencies(authManager: AuthManager, oAuthHandler: OAuthHandler? = nil) {
        self.authManager = authManager
        self.oAuthHandler = oAuthHandler
    }

    // MARK: - Actions

    func submit() async {
        guard isFormValid else { return }

        isLoading = true
        error = nil

        do {
            switch mode {
            case .login:
                try await login()
            case .signup:
                try await signup()
            }
        } catch {
            self.error = AppError(from: error)
        }

        isLoading = false
    }

    func toggleMode() {
        mode = mode == .login ? .signup : .login
        error = nil
        // Clear password when switching modes for security
        password = ""
        confirmPassword = ""
    }

    func clearError() {
        error = nil
    }

    func resetForm() {
        email = ""
        password = ""
        name = ""
        confirmPassword = ""
        error = nil
    }

    // MARK: - Login

    private func login() async throws {
        guard let authManager = authManager else {
            throw APIError.unknown
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try await authManager.login(email: trimmedEmail, password: password)
    }

    // MARK: - Signup

    private func signup() async throws {
        guard let authManager = authManager else {
            throw APIError.unknown
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        try await authManager.signup(name: trimmedName, email: trimmedEmail, password: password)
    }

    // MARK: - OAuth

    func startOAuth(provider: OAuthProvider) async {
        guard let oAuthHandler = oAuthHandler else {
            // Fallback: show OAuth URL directly
            if let url = URL(string: provider.authURL) {
                oAuthURL = url
                showOAuthSheet = true
            }
            return
        }

        isLoading = true
        error = nil

        do {
            try await oAuthHandler.startOAuth(provider: provider)
        } catch {
            self.error = AppError(from: error)
        }

        isLoading = false
    }

    func handleOAuthCallback(url: URL) async {
        guard let oAuthHandler = oAuthHandler else { return }

        isLoading = true
        error = nil

        do {
            try await oAuthHandler.handleCallback(url: url)
        } catch {
            self.error = AppError(from: error)
        }

        isLoading = false
    }

    func dismissOAuthSheet() {
        showOAuthSheet = false
        oAuthURL = nil
    }

    // MARK: - Validation

    /// Validates email format using a basic regex pattern
    private func validateEmail(_ email: String) -> ValidationResult {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic email regex pattern
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

        guard let regex = try? NSRegularExpression(pattern: emailPattern),
              let _ = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return .invalid(String(localized: "auth.validation.email.invalid"))
        }

        return .valid
    }

    /// Validates password requirements:
    /// - Minimum 8 characters
    /// - At least one uppercase letter
    /// - At least one lowercase letter
    /// - At least one digit
    private func validatePassword(_ password: String) -> ValidationResult {
        var issues: [String] = []

        if password.count < 8 {
            issues.append(String(localized: "auth.validation.password.minLength"))
        }

        if password.range(of: "[A-Z]", options: .regularExpression) == nil {
            issues.append(String(localized: "auth.validation.password.uppercase"))
        }

        if password.range(of: "[a-z]", options: .regularExpression) == nil {
            issues.append(String(localized: "auth.validation.password.lowercase"))
        }

        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            issues.append(String(localized: "auth.validation.password.digit"))
        }

        if issues.isEmpty {
            return .valid
        }

        return .invalid(issues.joined(separator: "\n"))
    }

    /// Validates name is not empty and has reasonable length
    private func validateName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < 2 {
            return .invalid(String(localized: "auth.validation.name.minLength"))
        }

        if trimmed.count > 100 {
            return .invalid(String(localized: "auth.validation.name.maxLength"))
        }

        return .valid
    }

    // MARK: - Password Strength

    var passwordStrength: PasswordStrength {
        guard !password.isEmpty else { return .none }

        var score = 0

        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        default: return .strong
        }
    }

    enum PasswordStrength: Sendable {
        case none
        case weak
        case medium
        case strong

        var displayName: String {
            switch self {
            case .none: return ""
            case .weak: return String(localized: "auth.password.strength.weak")
            case .medium: return String(localized: "auth.password.strength.medium")
            case .strong: return String(localized: "auth.password.strength.strong")
            }
        }

        var color: String {
            switch self {
            case .none: return "secondary"
            case .weak: return "appError"
            case .medium: return "appWarning"
            case .strong: return "appSuccess"
            }
        }
    }
}
