import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String, Sendable {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
}

// MARK: - API Endpoint

enum APIEndpoint: Sendable {
    // Auth
    case login
    case signup
    case logout
    case me
    case deleteAccount
    case googleAuth
    case yandexAuth
    case vkAuth

    // User
    case updateProfile

    // Wishlists
    case wishlists
    case wishlist(id: String)
    case createWishlist
    case updateWishlist(id: String)
    case deleteWishlist(id: String)

    // Items
    case addItem(wishlistId: String)
    case updateItem(wishlistId: String, itemId: String)
    case deleteItem(wishlistId: String, itemId: String)
    case resolveItem

    // Sharing
    case getByToken(token: String)
    case follow(token: String)
    case unfollow(wishlistId: String)
    case sharedWishlists

    var path: String {
        switch self {
        // Auth
        case .login:
            return "/auth/login"
        case .signup:
            return "/auth/signup"
        case .logout:
            return "/auth/logout"
        case .me:
            return "/auth/me"
        case .deleteAccount:
            return "/auth/me"
        case .googleAuth:
            return "/auth/google"
        case .yandexAuth:
            return "/auth/yandex"
        case .vkAuth:
            return "/auth/vk"

        // User
        case .updateProfile:
            return "/users/me"

        // Wishlists
        case .wishlists, .createWishlist:
            return "/wishlists"
        case .wishlist(let id), .updateWishlist(let id), .deleteWishlist(let id):
            return "/wishlists/\(id)"

        // Items
        case .addItem(let wishlistId):
            return "/wishlists/\(wishlistId)/items"
        case .updateItem(let wishlistId, let itemId):
            return "/wishlists/\(wishlistId)/items/\(itemId)"
        case .deleteItem(let wishlistId, let itemId):
            return "/wishlists/\(wishlistId)/items/\(itemId)"
        case .resolveItem:
            return "/wishlists/resolve-item"

        // Sharing
        case .getByToken(let token):
            return "/wishlists/get-by-token/\(token)"
        case .follow(let token):
            return "/wishlists/\(token)/follow"
        case .unfollow(let wishlistId):
            return "/wishlists/\(wishlistId)/unfollow"
        case .sharedWishlists:
            return "/wishlists/shared"
        }
    }

    var method: HTTPMethod {
        switch self {
        // Auth
        case .login, .signup, .logout:
            return .POST
        case .me:
            return .GET
        case .deleteAccount:
            return .DELETE
        case .googleAuth, .yandexAuth, .vkAuth:
            return .GET

        // User
        case .updateProfile:
            return .PATCH

        // Wishlists
        case .wishlists, .wishlist, .sharedWishlists:
            return .GET
        case .createWishlist:
            return .POST
        case .updateWishlist:
            return .PUT
        case .deleteWishlist:
            return .DELETE

        // Items
        case .addItem:
            return .POST
        case .updateItem:
            return .PATCH
        case .deleteItem:
            return .DELETE
        case .resolveItem:
            return .POST

        // Sharing
        case .getByToken:
            return .GET
        case .follow, .unfollow:
            return .POST
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .signup, .googleAuth, .yandexAuth, .vkAuth, .getByToken:
            return false
        default:
            return true
        }
    }
}
