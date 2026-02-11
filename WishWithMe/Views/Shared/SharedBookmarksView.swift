import SwiftUI
import SwiftData

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SharedBookmarksView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    let syncEngine: SyncEngine?
    @Binding var isTabBarCollapsed: Bool

    @State private var viewModel: WishlistsViewModel?
    @State private var bookmarkToRemove: Bookmark?
    @State private var showRemoveAlert: Bool = false
    @State private var headerInitialY: CGFloat?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                bookmarkContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Shared with me")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let syncEngine = syncEngine {
                    SyncStatusIndicator(state: syncEngine.state)
                }
            }
        }
        .alert("Remove Bookmark", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {
                bookmarkToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let bookmark = bookmarkToRemove, let viewModel = viewModel {
                    viewModel.deleteBookmark(bookmark)
                    HapticManager.impact(.medium)
                }
                bookmarkToRemove = nil
            }
        } message: {
            if let bookmark = bookmarkToRemove {
                Text("Remove \"\(bookmark.wishlistName ?? String(localized: "Shared Wishlist"))\" from your bookmarks?")
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = WishlistsViewModel(
                    modelContext: modelContext,
                    syncEngine: syncEngine,
                    authManager: authManager
                )
                viewModel = vm
            }
            viewModel?.syncEngine = syncEngine
            viewModel?.loadWishlists()
        }
        .onChange(of: syncEngine?.state) { _, newState in
            viewModel?.syncEngine = syncEngine
            if newState == .idle {
                viewModel?.loadWishlists()
            }
        }
    }

    @ViewBuilder
    private func bookmarkContent(viewModel: WishlistsViewModel) -> some View {
        if viewModel.bookmarks.isEmpty && !viewModel.isLoading {
            emptyState
                .refreshable { await viewModel.refresh() }
                .onAppear { isTabBarCollapsed = false }
        } else {
            List {
                Section {
                    ForEach(viewModel.bookmarks, id: \.id) { bookmark in
                        NavigationLink {
                            if let wId = bookmark.wishlistId {
                                SharedWishlistView(
                                    syncEngine: syncEngine,
                                    wishlistId: wId,
                                    isTabBarCollapsed: $isTabBarCollapsed
                                )
                                .environment(authManager)
                            }
                        } label: {
                            BookmarkRow(bookmark: bookmark, itemCount: viewModel.itemCount(for: bookmark), onRemove: {
                                bookmarkToRemove = bookmark
                                showRemoveAlert = true
                            })
                        }
                    }
                } header: {
                    Text("Shared with me")
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: proxy.frame(in: .global).minY
                                )
                            }
                        )
                }
            }
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                guard value > 0 else { return }
                if headerInitialY == nil {
                    headerInitialY = value
                }
                guard let initial = headerInitialY else { return }
                let delta = initial - value
                let shouldCollapse = delta > 20
                if shouldCollapse != isTabBarCollapsed {
                    isTabBarCollapsed = shouldCollapse
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No shared wishlists yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("When someone shares a wishlist with you, it will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}
