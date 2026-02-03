import SwiftUI

struct SharedWishlistsView: View {
    @Environment(\.dataController) private var dataController
    @Environment(\.apiClient) private var apiClient

    @State private var sharedWishlists: [Wishlist] = []
    @State private var viewState: ViewState<[Wishlist]> = .idle
    @Bindable var coordinator: WishlistsNavigationCoordinator

    var body: some View {
        Group {
            switch viewState {
            case .idle, .loading:
                if sharedWishlists.isEmpty {
                    LoadingView()
                } else {
                    wishlistsList
                }
            case .loaded:
                if sharedWishlists.isEmpty {
                    emptyView
                } else {
                    wishlistsList
                }
            case .empty:
                emptyView
            case .error(let error):
                ErrorView(error: error) {
                    Task { await loadSharedWishlists() }
                }
            }
        }
        .navigationTitle(String(localized: "wishlists.shared.title"))
        .refreshable {
            await loadSharedWishlists()
        }
        .task {
            if sharedWishlists.isEmpty {
                await loadSharedWishlists()
            }
        }
    }

    private var wishlistsList: some View {
        List {
            ForEach(sharedWishlists) { wishlist in
                Button {
                    coordinator.navigateToWishlistDetail(wishlist)
                } label: {
                    SharedWishlistRowView(wishlist: wishlist)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        unfollowWishlist(wishlist)
                    } label: {
                        Label(String(localized: "button.unfollow"), systemImage: "person.badge.minus")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label(
                String(localized: "wishlists.shared.empty.title"),
                systemImage: "person.2"
            )
        } description: {
            Text(String(localized: "wishlists.shared.empty.description"))
        }
    }

    private func loadSharedWishlists() async {
        viewState = .loading

        guard let apiClient = apiClient else {
            viewState = .error(AppError.unknown)
            return
        }

        do {
            let dtos = try await apiClient.getSharedWishlists()
            sharedWishlists = dtos.map { Wishlist(from: $0) }
            viewState = sharedWishlists.isEmpty ? .empty : .loaded(sharedWishlists)
        } catch {
            viewState = .error(AppError(from: error))
        }
    }

    private func unfollowWishlist(_ wishlist: Wishlist) {
        Task {
            do {
                try await apiClient?.unfollowWishlist(id: wishlist.id)
                sharedWishlists.removeAll { $0.id == wishlist.id }
                if sharedWishlists.isEmpty {
                    viewState = .empty
                }
            } catch {
                // Show error
            }
        }
    }
}

// MARK: - Shared Wishlist Row View

struct SharedWishlistRowView: View {
    let wishlist: Wishlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(wishlist.name)
                    .font(.headline)

                Spacer()

                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(String(localized: "wishlists.shared.owner \(wishlist.userName)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                    .foregroundStyle(dueDate < Date() ? .appError : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: AppError
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(error.title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            if error.isRetryable {
                Button {
                    onRetry()
                } label: {
                    Text(String(localized: "button.retry"))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Preview

#Preview("Shared Wishlists") {
    NavigationStack {
        SharedWishlistsView(coordinator: WishlistsNavigationCoordinator())
    }
    .withDependencies(DependencyContainer.preview)
}
