import Foundation

enum AppConfig {
    #if DEBUG
    static let apiBaseURL = "https://api.wishwith.me"
    #else
    static let apiBaseURL = "https://api.wishwith.me"
    #endif

    static let keychainService = "me.wishwith.app"
    static let accessTokenKey = "access_token"
    static let refreshTokenKey = "refresh_token"

    static let requestTimeout: TimeInterval = 30
}
