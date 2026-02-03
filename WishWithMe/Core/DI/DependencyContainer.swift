import Foundation
import SwiftUI

// MARK: - Dependency Container

@MainActor
final class DependencyContainer: ObservableObject {
    // MARK: - Services

    let keychainService: KeychainService
    let networkMonitor: NetworkMonitor
    let authManager: AuthManager
    let apiClient: APIClient
    let dataController: DataController

    // MARK: - Initialization

    init(inMemory: Bool = false) {
        // Initialize services
        self.keychainService = KeychainService()
        self.networkMonitor = NetworkMonitor()
        self.authManager = AuthManager(keychainService: keychainService)
        self.apiClient = APIClient()
        self.dataController = DataController(inMemory: inMemory)

        // Set up dependencies
        Task {
            await apiClient.setAuthManager(authManager)
        }
        authManager.setAPIClient(apiClient)

        // Start network monitoring
        networkMonitor.startMonitoring()
    }

    // MARK: - Preview Container

    static var preview: DependencyContainer {
        DependencyContainer(inMemory: true)
    }
}

// MARK: - Environment Keys

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

private struct AuthManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: AuthManager? = nil
}

private struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClient? = nil
}

private struct DataControllerKey: EnvironmentKey {
    @MainActor static let defaultValue: DataController? = nil
}

private struct NetworkMonitorKey: EnvironmentKey {
    static let defaultValue: NetworkMonitor? = nil
}

// MARK: - Environment Values Extension

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }

    var authManager: AuthManager? {
        get { self[AuthManagerKey.self] }
        set { self[AuthManagerKey.self] = newValue }
    }

    var apiClient: APIClient? {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var dataController: DataController? {
        get { self[DataControllerKey.self] }
        set { self[DataControllerKey.self] = newValue }
    }

    var networkMonitor: NetworkMonitor? {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }
}

// MARK: - View Extension for Dependency Injection

extension View {
    func withDependencies(_ container: DependencyContainer) -> some View {
        self
            .environment(\.dependencyContainer, container)
            .environment(\.authManager, container.authManager)
            .environment(\.apiClient, container.apiClient)
            .environment(\.dataController, container.dataController)
            .environment(\.networkMonitor, container.networkMonitor)
            .environmentObject(container)
    }
}
