import SwiftUI

struct MainTabView: View {
    @Environment(\.networkMonitor) private var networkMonitor
    @State private var selectedTab: Tab = .wishlists
    @State private var showOfflineBanner = false

    enum Tab: Hashable {
        case wishlists
        case profile
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                WishlistsNavigationView()
                    .tabItem {
                        Label(
                            String(localized: "tab.wishlists"),
                            systemImage: "list.bullet.clipboard"
                        )
                    }
                    .tag(Tab.wishlists)

                ProfileNavigationView()
                    .tabItem {
                        Label(
                            String(localized: "tab.profile"),
                            systemImage: "person.circle"
                        )
                    }
                    .tag(Tab.profile)
            }
            .tint(Color.appPrimary)

            // Offline Banner
            if showOfflineBanner {
                OfflineBannerView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showOfflineBanner)
        .onChange(of: networkMonitor?.isConnected) { _, isConnected in
            showOfflineBanner = !(isConnected ?? true)
        }
        .onAppear {
            showOfflineBanner = !(networkMonitor?.isConnected ?? true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .handleDeepLink)) { notification in
            handleDeepLink(notification)
        }
    }

    private func handleDeepLink(_ notification: Notification) {
        guard let deepLink = notification.userInfo?["deepLink"] as? DeepLink else { return }

        // Switch to wishlists tab for wishlist-related deep links
        switch deepLink {
        case .wishlist, .sharedWishlist, .followWishlist:
            selectedTab = .wishlists
        }
    }
}

// MARK: - Offline Banner View

struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.footnote.bold())

            Text(String(localized: "offline.banner"))
                .font(.footnote.bold())

            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appWarning)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Preview

#Preview("Main Tab View") {
    MainTabView()
        .withDependencies(DependencyContainer.preview)
}

#Preview("Offline Banner") {
    OfflineBannerView()
}
