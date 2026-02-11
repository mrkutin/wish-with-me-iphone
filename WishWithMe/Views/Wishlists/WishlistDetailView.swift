import SwiftUI
import SwiftData

struct WishlistDetailView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let wishlistId: String
    let syncEngine: SyncEngine?
    @Binding var isTabBarCollapsed: Bool

    @State private var viewModel: WishlistDetailViewModel?
    @State private var showAddItemSheet: Bool = false
    @State private var editingItem: Item?
    @State private var itemToDelete: Item?
    @State private var showDeleteItemAlert: Bool = false
    @State private var showEditWishlistSheet: Bool = false
    @State private var showDeleteWishlistAlert: Bool = false
    @State private var showShareSheet: Bool = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                mainContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel?.wishlist?.name ?? "Wishlist")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let syncEngine = syncEngine {
                    SyncStatusIndicator(state: syncEngine.state)
                }
            }
        }
        .sheet(isPresented: $showAddItemSheet) {
            if let viewModel = viewModel {
                AddItemSheet(
                    onCreateByURL: { url in
                        viewModel.createItemByURL(url: url)
                        HapticManager.notification(.success)
                    },
                    onCreateManually: { title, desc, price, currency, qty, src, img in
                        viewModel.createItemManually(
                            title: title,
                            description: desc,
                            price: price,
                            currency: currency,
                            quantity: qty,
                            sourceUrl: src,
                            imageBase64: img
                        )
                        HapticManager.notification(.success)
                    }
                )
            }
        }
        .sheet(item: $editingItem) { item in
            if let viewModel = viewModel {
                EditItemSheet(item: item) { title, desc, price, currency, qty, src, img in
                    viewModel.updateItem(
                        item,
                        title: title,
                        description: desc,
                        price: price,
                        currency: currency,
                        quantity: qty,
                        sourceUrl: src,
                        imageBase64: img
                    )
                }
            }
        }
        .sheet(isPresented: $showEditWishlistSheet) {
            if let viewModel = viewModel, let wishlist = viewModel.wishlist {
                CreateEditWishlistSheet(editingWishlist: wishlist) { name, desc, icon, iconColor in
                    viewModel.updateWishlist(name: name, description: desc, icon: icon, iconColor: iconColor)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(
                syncEngine: syncEngine,
                wishlistId: wishlistId
            )
        }
        .alert("Delete Item", isPresented: $showDeleteItemAlert) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete, let viewModel = viewModel {
                    viewModel.deleteItem(item)
                    HapticManager.impact(.medium)
                }
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete {
                Text("Are you sure you want to delete \"\(item.title)\"?")
            }
        }
        .alert("Delete Wishlist", isPresented: $showDeleteWishlistAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel?.deleteWishlist()
                HapticManager.impact(.medium)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this wishlist and all its items?")
        }
        .onAppear {
            if viewModel == nil {
                let vm = WishlistDetailViewModel(
                    wishlistId: wishlistId,
                    modelContext: modelContext,
                    syncEngine: syncEngine,
                    authManager: authManager
                )
                viewModel = vm
            }
            viewModel?.syncEngine = syncEngine
            viewModel?.loadData()
        }
        .onChange(of: syncEngine?.state) { _, newState in
            viewModel?.syncEngine = syncEngine
            if newState == .idle {
                viewModel?.loadData()
            }
        }
    }

    @ViewBuilder
    private func mainContent(viewModel: WishlistDetailViewModel) -> some View {
        if let wishlist = viewModel.wishlist {
            if viewModel.items.isEmpty && !viewModel.isLoading {
                emptyItemsState(wishlist: wishlist)
                    .refreshable {
                        await viewModel.refresh()
                    }
            } else {
                itemsList(viewModel: viewModel, wishlist: wishlist)
                    .refreshable {
                        await viewModel.refresh()
                    }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Wishlist not found")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func itemsList(viewModel: WishlistDetailViewModel, wishlist: Wishlist) -> some View {
        ScrollView {
            ScrollOffsetTracker(isScrolled: $isTabBarCollapsed)
            VStack(spacing: 0) {
                wishlistInfoRow(wishlist: wishlist)

                itemsSectionHeader

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.items, id: \.id) { item in
                        ItemCard(
                            item: item,
                            onEdit: {
                                editingItem = item
                            },
                            onDelete: {
                                itemToDelete = item
                                showDeleteItemAlert = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .onDisappear {
            isTabBarCollapsed = false
        }
    }

    @ViewBuilder
    private func wishlistInfoRow(wishlist: Wishlist) -> some View {
        if let description = wishlist.descriptionText, !description.isEmpty {
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 4)
        }
    }

    private var itemsSectionHeader: some View {
        HStack {
            Text("Items")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .tint(Color.brandPrimary)
            .accessibilityLabel("Share wishlist")

            Button {
                showAddItemSheet = true
            } label: {
                Label("Add Item", systemImage: "plus")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
            .accessibilityLabel("Add item")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func emptyItemsState(wishlist: Wishlist) -> some View {
        VStack(spacing: 0) {
            wishlistInfoRow(wishlist: wishlist)

            itemsSectionHeader

            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No items yet")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 16)

            Text("Add items by URL or manually")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()
        }
    }
}
