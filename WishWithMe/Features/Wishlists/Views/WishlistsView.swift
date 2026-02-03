import SwiftUI
import SwiftData

struct WishlistsView: View {
    @Environment(\.dataController) private var dataController
    @Environment(\.apiClient) private var apiClient
    @Environment(\.networkMonitor) private var networkMonitor

    @Query(
        filter: #Predicate<Wishlist> { !$0.pendingDeletion },
        sort: \Wishlist.updatedAt,
        order: .reverse
    )
    private var wishlists: [Wishlist]

    @State private var viewState: ViewState<[Wishlist]> = .idle
    @State private var searchText = ""
    @Bindable var coordinator: WishlistsNavigationCoordinator

    var filteredWishlists: [Wishlist] {
        if searchText.isEmpty {
            return wishlists
        }
        return wishlists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if wishlists.isEmpty && viewState.isLoading {
                LoadingView()
            } else if wishlists.isEmpty {
                EmptyWishlistsView {
                    coordinator.showCreateWishlist()
                }
            } else {
                wishlistsList
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "wishlists.search"))
        .refreshable {
            await refreshWishlists()
        }
        .task {
            await loadWishlists()
        }
    }

    private var wishlistsList: some View {
        List {
            ForEach(filteredWishlists) { wishlist in
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
            }
        }
        .listStyle(.plain)
    }

    private func loadWishlists() async {
        guard viewState.data == nil else { return }
        await refreshWishlists()
    }

    private func refreshWishlists() async {
        viewState = .loading

        guard let apiClient = apiClient else {
            viewState = .error(AppError.unknown)
            return
        }

        do {
            let dtos = try await apiClient.getWishlists()
            try dataController?.saveWishlists(dtos)
            viewState = .loaded(wishlists)
        } catch {
            // If offline, show cached data
            if !(networkMonitor?.isConnected ?? true) && !wishlists.isEmpty {
                viewState = .loaded(wishlists)
            } else {
                viewState = .error(AppError(from: error))
            }
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
                        try? dataController?.markWishlistForDeletion(wishlist)

                        if networkMonitor?.isConnected ?? false {
                            try? await apiClient?.deleteWishlist(id: wishlist.id)
                            try? dataController?.deleteWishlist(wishlist)
                        }
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
                    "\(wishlist.items.count)",
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
