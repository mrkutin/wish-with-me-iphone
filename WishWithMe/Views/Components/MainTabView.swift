import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self) private var authManager
    let syncEngine: SyncEngine?

    @State private var selectedTab: MainTab = .home
    @State private var isTabBarCollapsed: Bool = false

    private var shouldCollapse: Bool {
        isTabBarCollapsed && (selectedTab == .ownWishlists || selectedTab == .sharedWithMe)
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                NavigationStack {
                    HomeView(selectedTab: $selectedTab)
                }
            case .ownWishlists:
                WishlistsView(
                    syncEngine: syncEngine,
                    isTabBarCollapsed: $isTabBarCollapsed
                )
            case .sharedWithMe:
                NavigationStack {
                    SharedBookmarksView(
                        syncEngine: syncEngine,
                        isTabBarCollapsed: $isTabBarCollapsed
                    )
                }
            case .profile:
                NavigationStack {
                    ProfileView(syncEngine: syncEngine)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(
                selectedTab: $selectedTab,
                isCollapsed: shouldCollapse
            )
        }
    }
}
