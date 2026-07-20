import SwiftUI
import SwiftData

@main
struct WishWithMeApp: App {
    @State private var authManager = AuthManager()
    @State private var networkMonitor = NetworkMonitor()
    @State private var syncEngine: SyncEngine?
    @State private var pendingShareToken: String?
    @AppStorage("appLocale") private var appLocale: String = "en"
    private let localStore = LocalStore.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(syncEngine: syncEngine, pendingShareToken: $pendingShareToken)
                .id(appLocale)
                .environment(authManager)
                .environment(networkMonitor)
                .environment(\.locale, Locale(identifier: appLocale))
                .modelContainer(localStore.modelContainer)
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-clearKeychain") {
                        try? KeychainHelper.delete(key: AppConfig.accessTokenKey)
                        try? KeychainHelper.delete(key: AppConfig.refreshTokenKey)
                        localStore.clearAllData()
                    }
                    #endif
                    await authManager.loadStoredAuth()
                    if let userLocale = authManager.currentUser?.locale {
                        appLocale = userLocale
                    }
                    let engine = SyncEngine(
                        apiClient: .shared,
                        modelContainer: localStore.modelContainer,
                        networkMonitor: networkMonitor
                    )
                    syncEngine = engine
                    if authManager.isAuthenticated {
                        await engine.fullSync()
                        engine.startPeriodicSync()
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active, authManager.isAuthenticated {
                        Task {
                            await syncEngine?.triggerSync()
                        }
                    }
                }
                .onChange(of: networkMonitor.isConnected) { _, isConnected in
                    if isConnected, authManager.isAuthenticated {
                        Task {
                            await syncEngine?.triggerSync()
                        }
                    }
                }
                .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                    if isAuthenticated {
                        Task {
                            await syncEngine?.fullSync()
                            await syncEngine?.startPeriodicSync()
                        }
                    } else {
                        Task {
                            await syncEngine?.stopSync()
                        }
                    }
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle: wishwithme://s/{token}
        // Handle: https://wishwith.me/s/{token}
        let pathComponents = url.pathComponents

        if url.scheme == "wishwithme" {
            // wishwithme://s/{token} → host="s", path="/{token}"
            if url.host == "s", let token = pathComponents.last, token != "/" {
                pendingShareToken = token
            }
        } else if url.host == "wishwith.me" || url.host == "www.wishwith.me" {
            // https://wishwith.me/s/{token}
            if pathComponents.count >= 3 && pathComponents[1] == "s" {
                pendingShareToken = pathComponents[2]
            }
        }
    }
}
