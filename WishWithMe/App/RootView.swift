import SwiftUI

struct RootView: View {
    @Environment(\.authManager) private var authManager
    @State private var isInitialized = false

    var body: some View {
        Group {
            if !isInitialized {
                LaunchScreenView()
            } else {
                switch authManager?.state {
                case .authenticated:
                    MainTabView()
                case .unauthenticated, .unknown, .none:
                    AuthenticationView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isInitialized)
        .animation(.easeInOut(duration: 0.3), value: authManager?.isAuthenticated)
        .task {
            await initializeApp()
        }
    }

    private func initializeApp() async {
        // Add minimum delay for launch screen
        async let minDelay: () = Task.sleep(nanoseconds: 500_000_000)

        // Initialize auth
        await authManager?.initialize()

        // Wait for minimum delay
        try? await minDelay

        withAnimation {
            isInitialized = true
        }
    }
}

// MARK: - Launch Screen View

struct LaunchScreenView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.appPrimary
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Text("WishWithMe")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview("Root View") {
    RootView()
        .withDependencies(DependencyContainer.preview)
}

#Preview("Launch Screen") {
    LaunchScreenView()
}
