import SwiftUI

struct MainTabView: View {
    @Environment(\.networkMonitor) private var networkMonitor
    @Environment(\.syncEngine) private var syncEngine
    @State private var selectedTab: Tab = .wishlists
    @State private var showOfflineBanner = false
    @State private var showSyncBanner = false

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
                    .badge(pendingBadge)

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

            // Status Banners
            VStack(spacing: 0) {
                if showOfflineBanner {
                    OfflineBannerView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if showSyncBanner && !showOfflineBanner {
                    SyncBannerView(
                        isSyncing: syncEngine?.isSyncing ?? false,
                        pendingCount: syncEngine?.pendingOperationCount ?? 0
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showOfflineBanner)
        .animation(.easeInOut(duration: 0.3), value: showSyncBanner)
        .onChange(of: networkMonitor?.isConnected) { _, isConnected in
            showOfflineBanner = !(isConnected ?? true)
        }
        .onChange(of: syncEngine?.isSyncing) { _, isSyncing in
            showSyncBanner = isSyncing ?? false
        }
        .onChange(of: syncEngine?.pendingOperationCount) { _, count in
            // Show banner if there are pending operations
            let hasPending = (count ?? 0) > 0
            if hasPending && !(networkMonitor?.isConnected ?? true) {
                showSyncBanner = true
            } else if !hasPending && !(syncEngine?.isSyncing ?? false) {
                showSyncBanner = false
            }
        }
        .onAppear {
            showOfflineBanner = !(networkMonitor?.isConnected ?? true)
            updateSyncBannerVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: .handleDeepLink)) { notification in
            handleDeepLink(notification)
        }
    }

    // MARK: - Computed Properties

    private var pendingBadge: Int {
        let count = syncEngine?.pendingOperationCount ?? 0
        // Only show badge if there are pending operations and we're offline
        if count > 0 && !(networkMonitor?.isConnected ?? true) {
            return count
        }
        return 0
    }

    // MARK: - Private Methods

    private func handleDeepLink(_ notification: Notification) {
        guard let deepLink = notification.userInfo?["deepLink"] as? DeepLink else { return }

        // Switch to wishlists tab for wishlist-related deep links
        switch deepLink {
        case .wishlist, .sharedWishlist, .followWishlist:
            selectedTab = .wishlists
        }
    }

    private func updateSyncBannerVisibility() {
        let isSyncing = syncEngine?.isSyncing ?? false
        let hasPending = (syncEngine?.pendingOperationCount ?? 0) > 0
        showSyncBanner = isSyncing || (hasPending && !(networkMonitor?.isConnected ?? true))
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

// MARK: - Sync Banner View

struct SyncBannerView: View {
    let isSyncing: Bool
    let pendingCount: Int

    var body: some View {
        HStack(spacing: 8) {
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white)

                Text(String(localized: "sync.inProgress"))
                    .font(.footnote.bold())
            } else if pendingCount > 0 {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.footnote.bold())

                Text(String(localized: "sync.pending \(pendingCount)"))
                    .font(.footnote.bold())
            }

            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSyncing ? Color.appInfo : Color.appPrimary.opacity(0.8))
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

#Preview("Sync Banner - Syncing") {
    SyncBannerView(isSyncing: true, pendingCount: 3)
}

#Preview("Sync Banner - Pending") {
    SyncBannerView(isSyncing: false, pendingCount: 5)
}
