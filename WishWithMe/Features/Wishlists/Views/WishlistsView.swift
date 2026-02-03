import SwiftUI
import SwiftData

struct WishlistsView: View {
    @Environment(\.apiClient) private var apiClient
    @Environment(\.dataController) private var dataController
    @Environment(\.networkMonitor) private var networkMonitor
    @Environment(\.authManager) private var authManager

    @Bindable var coordinator: WishlistsNavigationCoordinator

    @State private var viewModel = WishlistsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.isEmpty {
                LoadingView()
            } else if viewModel.isEmpty {
                EmptyWishlistsView {
                    coordinator.showCreateWishlist()
                }
            } else {
                wishlistsList
            }
        }
        .searchable(text: $viewModel.searchText, prompt: String(localized: "wishlists.search"))
        .refreshable {
            await viewModel.refreshWishlists()
        }
        .task {
            await viewModel.loadWishlists()
        }
        .onAppear {
            setupDependencies()
        }
        .overlay(alignment: .top) {
            if viewModel.isOffline {
                offlineBanner
            }
        }
    }

    // MARK: - Wishlists List

    private var wishlistsList: some View {
        List {
            // Sync status section
            if viewModel.hasUnsyncedChanges {
                Section {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Color.appWarning)
                        Text(String(localized: "wishlists.pendingSync"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(String(localized: "button.syncNow")) {
                            Task {
                                await viewModel.syncPendingChanges()
                            }
                        }
                        .font(.subheadline)
                        .disabled(viewModel.isOffline)
                    }
                }
            }

            // Wishlists
            ForEach(viewModel.filteredWishlists) { wishlist in
                Button {
                    coordinator.navigateToWishlistDetail(wishlist)
                } label: {
                    WishlistRowView(wishlist: wishlist)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteWishlist(wishlist)
                    } label: {
                        Label(String(localized: "button.delete"), systemImage: "trash")
                    }

                    Button {
                        coordinator.showShareWishlist(wishlist)
                    } label: {
                        Label(String(localized: "button.share"), systemImage: "square.and.arrow.up")
                    }
                    .tint(Color.appPrimary)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        coordinator.showEditWishlist(wishlist)
                    } label: {
                        Label(String(localized: "button.edit"), systemImage: "pencil")
                    }
                    .tint(Color.appInfo)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(String(localized: "offline.banner"))
        }
        .font(.footnote.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appWarning)
        .clipShape(Capsule())
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: viewModel.isOffline)
    }

    // MARK: - Actions

    private func setupDependencies() {
        if let apiClient = apiClient,
           let dataController = dataController,
           let networkMonitor = networkMonitor,
           let authManager = authManager {
            viewModel.setDependencies(
                apiClient: apiClient,
                dataController: dataController,
                networkMonitor: networkMonitor,
                authManager: authManager
            )
        }
    }

    private func deleteWishlist(_ wishlist: Wishlist) {
        coordinator.showAlert(
            AlertItem.confirmation(
                title: String(localized: "wishlist.delete.title"),
                message: String(localized: "wishlist.delete.message"),
                confirmTitle: String(localized: "button.delete"),
                onConfirm: {
                    Task {
                        try? await viewModel.deleteWishlist(wishlist)
                    }
                }
            )
        )
    }
}

// MARK: - Wishlist Row View

struct WishlistRowView: View {
    let wishlist: Wishlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(wishlist.name)
                    .font(.headline)

                Spacer()

                if wishlist.needsSync {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Label(
                    "\(wishlist.items.filter { !$0.pendingDeletion }.count)",
                    systemImage: "gift"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let dueDate = wishlist.dueDate {
                    Label(
                        dueDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(dueDate < Date() ? Color.appError : .secondary)
                }

                Spacer()
            }

            if let description = wishlist.wishlistDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(wishlist.name)
        .accessibilityHint(String(localized: "wishlists.row.hint"))
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(String(localized: "loading"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Wishlists View

struct EmptyWishlistsView: View {
    let onCreate: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                String(localized: "wishlists.empty.title"),
                systemImage: "list.bullet.clipboard"
            )
        } description: {
            Text(String(localized: "wishlists.empty.description"))
        } actions: {
            Button {
                onCreate()
            } label: {
                Text(String(localized: "wishlists.create"))
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Preview

#Preview("Wishlists View") {
    NavigationStack {
        WishlistsView(coordinator: WishlistsNavigationCoordinator())
            .navigationTitle(String(localized: "wishlists.title"))
    }
    .withDependencies(DependencyContainer.preview)
}

#Preview("Empty Wishlists") {
    NavigationStack {
        EmptyWishlistsView {
            // Create action
        }
        .navigationTitle(String(localized: "wishlists.title"))
    }
}
