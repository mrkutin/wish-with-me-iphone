import Foundation
import KeychainAccess

// MARK: - Keychain Error

enum KeychainError: Error, LocalizedError {
    case saveFailed
    case loadFailed
    case deleteFailed
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save to Keychain"
        case .loadFailed:
            return "Failed to load from Keychain"
        case .deleteFailed:
            return "Failed to delete from Keychain"
        case .dataConversionFailed:
            return "Failed to convert data"
        }
    }
}

// MARK: - Keychain Keys

private enum KeychainKeys {
    static let authToken = "auth_token"
    static let refreshToken = "refresh_token"
    static let userId = "user_id"
    static let userEmail = "user_email"
}

// MARK: - Keychain Service

final class KeychainService: @unchecked Sendable {
    private let keychain: Keychain

    init(service: String = "com.wishwithme.app") {
        self.keychain = Keychain(service: service)
            .accessibility(.afterFirstUnlock)
    }

    // MARK: - Token Management

    func saveToken(_ token: String) throws {
        do {
            try keychain.set(token, key: KeychainKeys.authToken)
        } catch {
            throw KeychainError.saveFailed
        }
    }

    func loadToken() -> String? {
        return try? keychain.get(KeychainKeys.authToken)
    }

    func deleteToken() throws {
        do {
            try keychain.remove(KeychainKeys.authToken)
        } catch {
            throw KeychainError.deleteFailed
        }
    }

    // MARK: - Refresh Token Management

    func saveRefreshToken(_ token: String) throws {
        do {
            try keychain.set(token, key: KeychainKeys.refreshToken)
        } catch {
            throw KeychainError.saveFailed
        }
    }

    func loadRefreshToken() -> String? {
        return try? keychain.get(KeychainKeys.refreshToken)
    }

    func deleteRefreshToken() throws {
        do {
            try keychain.remove(KeychainKeys.refreshToken)
        } catch {
            throw KeychainError.deleteFailed
        }
    }

    // MARK: - User Info

    func saveUserId(_ userId: String) throws {
        do {
            try keychain.set(userId, key: KeychainKeys.userId)
        } catch {
            throw KeychainError.saveFailed
        }
    }

    func loadUserId() -> String? {
        return try? keychain.get(KeychainKeys.userId)
    }

    func saveUserEmail(_ email: String) throws {
        do {
            try keychain.set(email, key: KeychainKeys.userEmail)
        } catch {
            throw KeychainError.saveFailed
        }
    }

    func loadUserEmail() -> String? {
        return try? keychain.get(KeychainKeys.userEmail)
    }

    // MARK: - Clear All

    func clearAll() throws {
        do {
            try keychain.removeAll()
        } catch {
            throw KeychainError.deleteFailed
        }
    }

    // MARK: - Generic Storage

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        do {
            try keychain.set(string, key: key)
        } catch {
            throw KeychainError.saveFailed
        }
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let string = try? keychain.get(key),
              let data = string.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    func delete(forKey key: String) throws {
        do {
            try keychain.remove(key)
        } catch {
            throw KeychainError.deleteFailed
        }
    }
}
