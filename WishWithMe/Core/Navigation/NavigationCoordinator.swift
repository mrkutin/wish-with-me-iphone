import Foundation
import SwiftUI
import Observation

// MARK: - Wishlists Navigation Destination

enum WishlistsDestination: Hashable {
    case wishlistDetail(Wishlist)
    case itemDetail(WishlistItem)
    case createWishlist
    case editWishlist(Wishlist)
    case addItem(Wishlist)
    case editItem(WishlistItem)
    case shareWishlist(Wishlist)
}

// MARK: - Profile Navigation Destination

enum ProfileDestination: Hashable {
    case settings
    case editProfile
    case changePassword
    case about
}

// MARK: - Deep Link

enum DeepLink: Equatable {
    case wishlist(id: String)
    case sharedWishlist(token: String)
    case followWishlist(token: String)

    /// Validates that an ID or token contains only safe characters (alphanumeric + hyphen + underscore)
    /// and has a reasonable length (1-128 characters)
    private static func isValidIdentifier(_ value: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_-]{1,128}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    init?(url: URL) {
        // Handle custom URL scheme: wishwithme://
        if url.scheme == "wishwithme" {
            switch url.host {
            case "wishlist":
                if let id = url.pathComponents.dropFirst().first,
                   Self.isValidIdentifier(id) {
                    self = .wishlist(id: id)
                    return
                }
            case "share", "follow":
                if let token = url.pathComponents.dropFirst().first,
                   Self.isValidIdentifier(token) {
                    self = .followWishlist(token: token)
                    return
                }
            default:
                break
            }
        }

        // Handle universal links: https://wishwith.me/
        if url.host == "wishwith.me" || url.host == "www.wishwith.me" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }

            if pathComponents.count >= 2 {
                switch pathComponents[0] {
                case "wishlists":
                    if pathComponents[1] == "follow", pathComponents.count >= 3 {
                        let token = pathComponents[2]
                        guard Self.isValidIdentifier(token) else { return nil }
                        self = .followWishlist(token: token)
                        return
                    } else {
                        let id = pathComponents[1]
                        guard Self.isValidIdentifier(id) else { return nil }
                        self = .wishlist(id: id)
                        return
                    }
                case "share":
                    let token = pathComponents[1]
                    guard Self.isValidIdentifier(token) else { return nil }
                    self = .sharedWishlist(token: token)
                    return
                default:
                    break
                }
            }
        }

        return nil
    }
}

// MARK: - Wishlists Navigation Coordinator

@Observable
@MainActor
final class WishlistsNavigationCoordinator {
    var path = NavigationPath()
    var presentedSheet: WishlistsSheet?
    var presentedAlert: AlertItem?

    private var pendingDeepLink: DeepLink?

    enum WishlistsSheet: Identifiable {
        case createWishlist
        case editWishlist(Wishlist)
        case addItem(Wishlist)
        case editItem(WishlistItem)
        case shareWishlist(Wishlist)
        case followWishlist(token: String)

        var id: String {
            switch self {
            case .createWishlist:
                return "createWishlist"
            case .editWishlist(let wishlist):
                return "editWishlist-\(wishlist.id)"
            case .addItem(let wishlist):
                return "addItem-\(wishlist.id)"
            case .editItem(let item):
                return "editItem-\(item.id)"
            case .shareWishlist(let wishlist):
                return "shareWishlist-\(wishlist.id)"
            case .followWishlist(let token):
                return "followWishlist-\(token)"
            }
        }
    }

    // MARK: - Navigation

    func navigate(to destination: WishlistsDestination) {
        path.append(destination)
    }

    func navigateToWishlistDetail(_ wishlist: Wishlist) {
        path.append(WishlistsDestination.wishlistDetail(wishlist))
    }

    func navigateToItemDetail(_ item: WishlistItem) {
        path.append(WishlistsDestination.itemDetail(item))
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    // MARK: - Sheets

    func showCreateWishlist() {
        presentedSheet = .createWishlist
    }

    func showEditWishlist(_ wishlist: Wishlist) {
        presentedSheet = .editWishlist(wishlist)
    }

    func showAddItem(to wishlist: Wishlist) {
        presentedSheet = .addItem(wishlist)
    }

    func showEditItem(_ item: WishlistItem) {
        presentedSheet = .editItem(item)
    }

    func showShareWishlist(_ wishlist: Wishlist) {
        presentedSheet = .shareWishlist(wishlist)
    }

    func showFollowWishlist(token: String) {
        presentedSheet = .followWishlist(token: token)
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    // MARK: - Alerts

    func showAlert(_ alert: AlertItem) {
        presentedAlert = alert
    }

    func dismissAlert() {
        presentedAlert = nil
    }

    // MARK: - Deep Links

    func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .wishlist(let id):
            // Navigate to specific wishlist
            // This would need to fetch the wishlist first
            pendingDeepLink = deepLink
        case .sharedWishlist(let token), .followWishlist(let token):
            showFollowWishlist(token: token)
        }
    }

    func processPendingDeepLink(with dataController: DataController) {
        guard let deepLink = pendingDeepLink else { return }
        pendingDeepLink = nil

        switch deepLink {
        case .wishlist(let id):
            if let wishlist = try? dataController.getWishlist(id: id) {
                navigateToWishlistDetail(wishlist)
            }
        default:
            break
        }
    }
}

// MARK: - Profile Navigation Coordinator

@Observable
@MainActor
final class ProfileNavigationCoordinator {
    var path = NavigationPath()
    var presentedSheet: ProfileSheet?
    var presentedAlert: AlertItem?

    enum ProfileSheet: Identifiable {
        case editProfile
        case changePassword

        var id: String {
            switch self {
            case .editProfile:
                return "editProfile"
            case .changePassword:
                return "changePassword"
            }
        }
    }

    // MARK: - Navigation

    func navigate(to destination: ProfileDestination) {
        path.append(destination)
    }

    func navigateToSettings() {
        path.append(ProfileDestination.settings)
    }

    func navigateToEditProfile() {
        path.append(ProfileDestination.editProfile)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    // MARK: - Sheets

    func showEditProfile() {
        presentedSheet = .editProfile
    }

    func showChangePassword() {
        presentedSheet = .changePassword
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    // MARK: - Alerts

    func showAlert(_ alert: AlertItem) {
        presentedAlert = alert
    }

    func dismissAlert() {
        presentedAlert = nil
    }
}

// MARK: - Alert Item

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: AlertButton
    let secondaryButton: AlertButton?

    struct AlertButton {
        let title: String
        let role: ButtonRole?
        let action: () -> Void

        init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void = {}) {
            self.title = title
            self.role = role
            self.action = action
        }
    }

    static func error(_ error: AppError, retryAction: (() -> Void)? = nil) -> AlertItem {
        if error.isRetryable, let retryAction = retryAction {
            return AlertItem(
                title: error.title,
                message: error.message,
                primaryButton: AlertButton(title: String(localized: "button.retry"), action: retryAction),
                secondaryButton: AlertButton(title: String(localized: "button.cancel"), role: .cancel)
            )
        } else {
            return AlertItem(
                title: error.title,
                message: error.message,
                primaryButton: AlertButton(title: String(localized: "button.ok")),
                secondaryButton: nil
            )
        }
    }

    static func confirmation(
        title: String,
        message: String,
        confirmTitle: String = String(localized: "button.confirm"),
        confirmRole: ButtonRole? = .destructive,
        onConfirm: @escaping () -> Void
    ) -> AlertItem {
        AlertItem(
            title: title,
            message: message,
            primaryButton: AlertButton(title: confirmTitle, role: confirmRole, action: onConfirm),
            secondaryButton: AlertButton(title: String(localized: "button.cancel"), role: .cancel)
        )
    }
}
