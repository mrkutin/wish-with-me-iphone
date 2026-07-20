import SwiftUI
import SwiftData

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct WishlistsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    let syncEngine: SyncEngine?
    @Binding var isTabBarCollapsed: Bool

    @State private var viewModel: WishlistsViewModel?
    @State private var showCreateSheet: Bool = false
    @State private var editingWishlist: Wishlist?
    @State private var wishlistToDelete: Wishlist?
    @State private var showDeleteAlert: Bool = false
    @State private var sharingWishlist: Wishlist?
    @State private var headerInitialY: CGFloat?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    wishlistContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("My Wishlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(width: 34, height: 34)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Create new wishlist")

                        if let syncEngine = syncEngine {
                            SyncStatusIndicator(state: syncEngine.state)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                if let viewModel = viewModel {
                    CreateEditWishlistSheet { name, description, icon, iconColor in
                        viewModel.createWishlist(
                            name: name,
                            description: description,
                            icon: icon,
                            iconColor: iconColor
                        )
                        HapticManager.notification(.success)
                    }
                }
            }
            .sheet(item: $editingWishlist) { wishlist in
                if let viewModel = viewModel {
                    CreateEditWishlistSheet(editingWishlist: wishlist) { name, description, icon, iconColor in
                        viewModel.updateWishlist(
                            wishlist,
                            name: name,
                            description: description,
                            icon: icon,
                            iconColor: iconColor
                        )
                    }
                }
            }
            .alert("Delete Wishlist", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    wishlistToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let wishlist = wishlistToDelete, let viewModel = viewModel {
                        viewModel.deleteWishlist(wishlist)
                        HapticManager.impact(.medium)
                    }
                    wishlistToDelete = nil
                }
            } message: {
                if let wishlist = wishlistToDelete {
                    Text("Are you sure you want to delete \"\(wishlist.name)\"? This will also delete all items in this wishlist.")
                }
            }
            .sheet(item: $sharingWishlist) { wishlist in
                ShareSheet(
                    syncEngine: syncEngine,
                    wishlistId: wishlist.id
                )
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
            .onReceive(NotificationCenter.default.publisher(for: .itemsDidChange)) { _ in
                viewModel?.refreshItemCounts()
            }
        }
    }

    @ViewBuilder
    private func wishlistContent(viewModel: WishlistsViewModel) -> some View {
        if viewModel.wishlists.isEmpty && !viewModel.isLoading {
            emptyState
                .refreshable {
                    await viewModel.refresh()
                }
                .onAppear { isTabBarCollapsed = false }
        } else {
            List {
                Section {
                ForEach(viewModel.wishlists, id: \.id) { wishlist in
                    NavigationLink {
                        WishlistDetailView(
                            wishlistId: wishlist.id,
                            syncEngine: syncEngine,
                            isTabBarCollapsed: $isTabBarCollapsed
                        )
                    } label: {
                        WishlistRow(
                            wishlist: wishlist,
                            itemCount: viewModel.itemCount(for: wishlist),
                            onShare: {
                                sharingWishlist = wishlist
                            },
                            onEdit: {
                                editingWishlist = wishlist
                            },
                            onDelete: {
                                wishlistToDelete = wishlist
                                showDeleteAlert = true
                            }
                        )
                    }
                }
                } header: {
                    Color.clear
                        .frame(height: 0)
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
                let shouldCollapse = delta > 3
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

            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No wishlists yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Create your first wishlist to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showCreateSheet = true
            } label: {
                Label("New Wishlist", systemImage: "plus")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}
