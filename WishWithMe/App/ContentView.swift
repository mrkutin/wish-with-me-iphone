import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    let syncEngine: SyncEngine?
    @Binding var pendingShareToken: String?

    @State private var showSharedWishlist: Bool = false
    @State private var activeShareToken: String?

    var body: some View {
        VStack(spacing: 0) {
            OfflineBanner(isOffline: !networkMonitor.isConnected)

            Group {
                if authManager.isAuthenticated {
                    MainTabView(syncEngine: syncEngine)
                } else {
                    LoginView(viewModel: AuthViewModel(authManager: authManager))
                }
            }
        }
        .sheet(isPresented: $showSharedWishlist) {
            if let token = activeShareToken {
                NavigationStack {
                    SharedWishlistView(
                        syncEngine: syncEngine,
                        shareToken: token
                    )
                    .environment(authManager)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                showSharedWishlist = false
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: pendingShareToken) { _, newToken in
            consumePendingToken(newToken)
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                consumePendingToken(pendingShareToken)
            }
        }
    }

    private func consumePendingToken(_ token: String?) {
        guard let token = token, authManager.isAuthenticated else { return }
        activeShareToken = token
        pendingShareToken = nil
        showSharedWishlist = true
    }
}
