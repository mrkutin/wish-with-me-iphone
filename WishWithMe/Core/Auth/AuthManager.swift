import Foundation
import Observation

// MARK: - Auth State

enum AuthState: Sendable {
    case unknown
    case authenticated(UserDTO)
    case unauthenticated
}

// MARK: - Auth Manager

@Observable
@MainActor
final class AuthManager {
    private let keychainService: KeychainService
    private var apiClient: APIClient?

    private(set) var state: AuthState = .unknown
    private(set) var token: String?
    private(set) var currentUser: UserDTO?
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    var isAuthenticated: Bool {
        if case .authenticated = state {
            return true
        }
        return false
    }

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        self.token = keychainService.loadToken()
    }

    func setAPIClient(_ client: APIClient) {
        self.apiClient = client
    }

    // MARK: - Initialize

    func initialize() async {
        guard let savedToken = keychainService.loadToken() else {
            state = .unauthenticated
            return
        }

        token = savedToken
        isLoading = true
        error = nil

        do {
            guard let apiClient = apiClient else {
                state = .unauthenticated
                isLoading = false
                return
            }

            let user = try await apiClient.getCurrentUser()
            currentUser = user
            state = .authenticated(user)
        } catch {
            // Token is invalid, clear it
            self.error = error
            await logout()
        }

        isLoading = false
    }

    // MARK: - Login

    func login(email: String, password: String) async throws {
        guard let apiClient = apiClient else {
            throw APIError.unknown
        }

        isLoading = true
        error = nil

        do {
            let response = try await apiClient.login(email: email, password: password)
            try saveAuthResponse(response)
            state = .authenticated(response.user)
        } catch {
            self.error = error
            isLoading = false
            throw error
        }

        isLoading = false
    }

    // MARK: - Signup

    func signup(name: String, email: String, password: String) async throws {
        guard let apiClient = apiClient else {
            throw APIError.unknown
        }

        isLoading = true
        error = nil

        do {
            let response = try await apiClient.signup(name: name, email: email, password: password)
            try saveAuthResponse(response)
            state = .authenticated(response.user)
        } catch {
            self.error = error
            isLoading = false
            throw error
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() async {
        // Try to logout on server (ignore errors)
        if let apiClient = apiClient, token != nil {
            try? await apiClient.logout()
        }

        clearAuth()
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let apiClient = apiClient else {
            throw APIError.unknown
        }

        isLoading = true
        error = nil

        do {
            try await apiClient.deleteAccount()
            clearAuth()
        } catch {
            self.error = error
            isLoading = false
            throw error
        }

        isLoading = false
    }

    // MARK: - Update Profile

    func updateProfile(name: String?, email: String?, password: String?) async throws {
        guard let apiClient = apiClient else {
            throw APIError.unknown
        }

        isLoading = true
        error = nil

        do {
            let updatedUser = try await apiClient.updateProfile(name: name, email: email, password: password)
            currentUser = updatedUser
            state = .authenticated(updatedUser)

            if let email = email {
                try keychainService.saveUserEmail(email)
            }
        } catch {
            self.error = error
            isLoading = false
            throw error
        }

        isLoading = false
    }

    // MARK: - OAuth Token Handling

    func handleOAuthToken(_ token: String) async throws {
        guard let apiClient = apiClient else {
            throw APIError.unknown
        }

        self.token = token
        try keychainService.saveToken(token)

        isLoading = true
        error = nil

        do {
            let user = try await apiClient.getCurrentUser()
            currentUser = user
            try keychainService.saveUserId(user.id)
            try keychainService.saveUserEmail(user.email)
            state = .authenticated(user)
        } catch {
            self.error = error
            clearAuth()
            isLoading = false
            throw error
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func saveAuthResponse(_ response: AuthResponse) throws {
        token = response.token
        currentUser = response.user

        try keychainService.saveToken(response.token)
        try keychainService.saveUserId(response.user.id)
        try keychainService.saveUserEmail(response.user.email)
    }

    private func clearAuth() {
        token = nil
        currentUser = nil
        state = .unauthenticated

        try? keychainService.clearAll()
    }
}
