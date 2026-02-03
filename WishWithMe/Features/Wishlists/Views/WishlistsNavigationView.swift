import SwiftUI

struct WishlistsNavigationView: View {
    @Environment(\.dataController) private var dataController
    @State private var coordinator = WishlistsNavigationCoordinator()
    @State private var selectedSegment: WishlistSegment = .mine

    enum WishlistSegment: String, CaseIterable {
        case mine
        case shared

        var title: String {
            switch self {
            case .mine: return String(localized: "wishlists.segment.mine")
            case .shared: return String(localized: "wishlists.segment.shared")
            }
        }
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            VStack(spacing: 0) {
                // Segment Picker
                Picker("", selection: $selectedSegment) {
                    ForEach(WishlistSegment.allCases, id: \.self) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content
                Group {
                    switch selectedSegment {
                    case .mine:
                        WishlistsView(coordinator: coordinator)
                    case .shared:
                        SharedWishlistsView(coordinator: coordinator)
                    }
                }
            }
            .navigationTitle(String(localized: "wishlists.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        coordinator.showCreateWishlist()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "wishlists.create"))
                }
            }
            .navigationDestination(for: WishlistsDestination.self) { destination in
                switch destination {
                case .wishlistDetail(let wishlist):
                    WishlistDetailView(wishlist: wishlist, coordinator: coordinator)
                case .itemDetail(let item):
                    ItemDetailView(item: item, coordinator: coordinator)
                case .createWishlist:
                    CreateWishlistView()
                case .editWishlist(let wishlist):
                    EditWishlistView(wishlist: wishlist)
                case .addItem(let wishlist):
                    AddItemSheet(wishlist: wishlist)
                case .editItem(let item):
                    EditItemSheet(item: item)
                case .shareWishlist(let wishlist):
                    ShareWishlistSheet(wishlist: wishlist)
                }
            }
        }
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert(item: $coordinator.presentedAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: alertButton(from: alert.primaryButton),
                secondaryButton: alert.secondaryButton.map { alertButton(from: $0) } ?? .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .handleDeepLink)) { notification in
            if let deepLink = notification.userInfo?["deepLink"] as? DeepLink {
                coordinator.handleDeepLink(deepLink)
            }
        }
        .onAppear {
            if let dataController = dataController {
                coordinator.processPendingDeepLink(with: dataController)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: WishlistsNavigationCoordinator.WishlistsSheet) -> some View {
        switch sheet {
        case .createWishlist:
            CreateWishlistView()
        case .editWishlist(let wishlist):
            EditWishlistView(wishlist: wishlist)
        case .addItem(let wishlist):
            AddItemSheet(wishlist: wishlist)
        case .editItem(let item):
            EditItemSheet(item: item)
        case .shareWishlist(let wishlist):
            ShareWishlistSheet(wishlist: wishlist)
        case .followWishlist(let token):
            FollowWishlistView(token: token)
        }
    }

    private func alertButton(from button: AlertItem.AlertButton) -> Alert.Button {
        switch button.role {
        case .destructive:
            return .destructive(Text(button.title), action: button.action)
        case .cancel:
            return .cancel(Text(button.title), action: button.action)
        default:
            return .default(Text(button.title), action: button.action)
        }
    }
}

// MARK: - Preview

#Preview("Wishlists Navigation") {
    WishlistsNavigationView()
        .withDependencies(DependencyContainer.preview)
}
