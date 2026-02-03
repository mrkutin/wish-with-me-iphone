import SwiftUI
import SwiftData

@main
struct WishWithMeApp: App {
    @State private var dependencyContainer = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .withDependencies(dependencyContainer)
                .modelContainer(dependencyContainer.dataController.modelContainer)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let deepLink = DeepLink(url: url) else { return }

        // Post notification for deep link handling
        NotificationCenter.default.post(
            name: .handleDeepLink,
            object: nil,
            userInfo: ["deepLink": deepLink]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let handleDeepLink = Notification.Name("handleDeepLink")
}
