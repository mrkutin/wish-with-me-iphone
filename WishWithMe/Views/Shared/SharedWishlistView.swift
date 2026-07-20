import SwiftUI
import SwiftData

struct SharedWishlistView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let syncEngine: SyncEngine?

    let shareToken: String?
    let wishlistId: String?
    @Binding var isTabBarCollapsed: Bool

    @State private var viewModel: SharedWishlistViewModel?

    init(syncEngine: SyncEngine?, shareToken: String? = nil, wishlistId: String? = nil, isTabBarCollapsed: Binding<Bool> = .constant(false)) {
        self.syncEngine = syncEngine
        self.shareToken = shareToken
        self.wishlistId = wishlistId
        self._isTabBarCollapsed = isTabBarCollapsed
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel?.wishlist?.name ?? String(localized: "Shared Wishlist"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let syncEngine = syncEngine {
                    SyncStatusIndicator(state: syncEngine.state)
                }
            }
        }
        .onAppear {
            setupViewModel()
        }
        .onChange(of: syncEngine?.state) { _, newState in
            viewModel?.syncEngine = syncEngine
            if newState == .idle {
                viewModel?.loadData()
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: SharedWishlistViewModel) -> some View {
        if viewModel.isLoading {
            VStack(spacing: 16) {
                ProgressView()
                Text("Loading shared wishlist...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Could not load wishlist")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task {
                        if let token = shareToken {
                            await viewModel.grantAccessAndSync(token: token)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
            }
            .padding()
        } else if let wishlist = viewModel.wishlist {
            wishlistContent(viewModel: viewModel, wishlist: wishlist)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Wishlist not found")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func wishlistContent(viewModel: SharedWishlistViewModel, wishlist: Wishlist) -> some View {
        ScrollView {
            ScrollOffsetTracker(isScrolled: $isTabBarCollapsed)
            VStack(alignment: .leading, spacing: 12) {
                // Owner info from bookmark
                if let bookmark = viewModel.bookmark {
                    HStack(spacing: 10) {
                        ownerAvatar(bookmark: bookmark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bookmark.ownerName ?? String(localized: "Someone"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("shared this wishlist with you")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(bookmark.ownerName ?? String(localized: "Someone")) shared this wishlist with you")
                }

                if let description = wishlist.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                if viewModel.items.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No items yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("The wishlist owner hasn't added any items")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.items, id: \.id) { item in
                            SharedItemCard(
                                item: item,
                                myMark: viewModel.myMarkForItem(item),
                                totalMarked: viewModel.totalMarked(for: item),
                                canMark: viewModel.canMark(item),
                                canMarkItems: viewModel.canMarkItems,
                                onMark: { viewModel.markItem(item) },
                                onUnmark: { viewModel.unmarkItem(item) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
        .onDisappear {
            isTabBarCollapsed = false
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func ownerAvatar(bookmark: Bookmark) -> some View {
        AvatarView(
            name: bookmark.ownerName,
            avatarBase64: bookmark.ownerAvatarBase64,
            size: 36
        )
    }

    private func setupViewModel() {
        if viewModel == nil {
            let vm = SharedWishlistViewModel(
                modelContext: modelContext,
                syncEngine: syncEngine,
                authManager: authManager,
                wishlistId: wishlistId
            )
            viewModel = vm
        }
        viewModel?.syncEngine = syncEngine

        if let token = shareToken, !viewModel!.grantSuccess {
            Task {
                await viewModel?.grantAccessAndSync(token: token)
            }
        } else if let wId = wishlistId {
            viewModel?.loadFromBookmark(wishlistId: wId)
        }
    }
}
