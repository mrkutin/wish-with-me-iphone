import SwiftUI

struct WishlistsNavigationView: View {
    @Environment(\.dataController) private var dataController
    @State private var coordinator = WishlistsNavigationCoordinator()
    @State private var selectedSegment: WishlistSegment = .mine

    enum WishlistSegment: String, CaseIterable {
        case mine
        case shared

        var title: String {
            switch self {
            case .mine: return String(localized: "wishlists.segment.mine")
            case .shared: return String(localized: "wishlists.segment.shared")
            }
        }
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            VStack(spacing: 0) {
                // Segment Picker
                Picker("", selection: $selectedSegment) {
                    ForEach(WishlistSegment.allCases, id: \.self) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content
                Group {
                    switch selectedSegment {
                    case .mine:
                        WishlistsView(coordinator: coordinator)
                    case .shared:
                        SharedWishlistsView(coordinator: coordinator)
                    }
                }
            }
            .navigationTitle(String(localized: "wishlists.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        coordinator.showCreateWishlist()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "wishlists.create"))
                }
            }
            .navigationDestination(for: WishlistsDestination.self) { destination in
                switch destination {
                case .wishlistDetail(let wishlist):
                    WishlistDetailView(wishlist: wishlist, coordinator: coordinator)
                case .itemDetail(let item):
                    ItemDetailView(item: item, coordinator: coordinator)
                case .createWishlist:
                    CreateWishlistView()
                case .editWishlist(let wishlist):
                    EditWishlistView(wishlist: wishlist)
                case .addItem(let wishlist):
                    AddItemSheet(wishlist: wishlist)
                case .editItem(let item):
                    EditItemSheet(item: item)
                case .shareWishlist(let wishlist):
                    ShareWishlistView(wishlist: wishlist)
                }
            }
        }
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert(item: $coordinator.presentedAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: alertButton(from: alert.primaryButton),
                secondaryButton: alert.secondaryButton.map { alertButton(from: $0) } ?? .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .handleDeepLink)) { notification in
            if let deepLink = notification.userInfo?["deepLink"] as? DeepLink {
                coordinator.handleDeepLink(deepLink)
            }
        }
        .onAppear {
            if let dataController = dataController {
                coordinator.processPendingDeepLink(with: dataController)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: WishlistsNavigationCoordinator.WishlistsSheet) -> some View {
        switch sheet {
        case .createWishlist:
            CreateWishlistView()
        case .editWishlist(let wishlist):
            EditWishlistView(wishlist: wishlist)
        case .addItem(let wishlist):
            AddItemSheet(wishlist: wishlist)
        case .editItem(let item):
            EditItemSheet(item: item)
        case .shareWishlist(let wishlist):
            ShareWishlistView(wishlist: wishlist)
        case .followWishlist(let token):
            FollowWishlistView(token: token)
        }
    }

    private func alertButton(from button: AlertItem.AlertButton) -> Alert.Button {
        switch button.role {
        case .destructive:
            return .destructive(Text(button.title), action: button.action)
        case .cancel:
            return .cancel(Text(button.title), action: button.action)
        default:
            return .default(Text(button.title), action: button.action)
        }
    }
}

// MARK: - Share Wishlist View

struct ShareWishlistView: View {
    @Environment(\.dismiss) private var dismiss
    let wishlist: Wishlist

    @State private var isCopied = false

    private var shareURL: URL? {
        URL(string: "https://wishwith.me/wishlists/follow/\(wishlist.sharedToken)")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // QR Code placeholder
                VStack(spacing: 16) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 120))
                        .foregroundStyle(Color.appPrimary)

                    Text(String(localized: "share.qrcode.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.appSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Share Link
                VStack(spacing: 12) {
                    Text(String(localized: "share.link.title"))
                        .font(.headline)

                    if let url = shareURL {
                        Text(url.absoluteString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    HStack(spacing: 16) {
                        // Copy Link
                        Button {
                            if let url = shareURL {
                                UIPasteboard.general.string = url.absoluteString
                                withAnimation {
                                    isCopied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        isCopied = false
                                    }
                                }
                            }
                        } label: {
                            Label(
                                isCopied
                                    ? String(localized: "share.copied")
                                    : String(localized: "share.copyLink"),
                                systemImage: isCopied ? "checkmark" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isCopied ? Color.appSuccess : Color.appPrimary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // System Share
                        if let url = shareURL {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(Color.appSecondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                Spacer()

                // Info
                VStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)

                    Text(String(localized: "share.info"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle(String(localized: "share.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Follow Wishlist View

struct FollowWishlistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var apiClient
    @Environment(\.dataController) private var dataController

    let token: String

    @State private var isLoading = true
    @State private var wishlist: WishlistDTO?
    @State private var error: AppError?
    @State private var isFollowing = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if let error = error {
                    errorView(error)
                } else if let wishlist = wishlist {
                    wishlistPreview(wishlist)
                }
            }
            .navigationTitle(String(localized: "wishlists.follow.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadWishlist()
            }
        }
    }

    private func errorView(_ error: AppError) -> some View {
        ContentUnavailableView {
            Label(error.title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            if error.isRetryable {
                Button(String(localized: "button.retry")) {
                    Task {
                        await loadWishlist()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func wishlistPreview(_ wishlist: WishlistDTO) -> some View {
        VStack(spacing: 24) {
            // Wishlist Info
            VStack(spacing: 16) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.appPrimary)

                Text(wishlist.name)
                    .font(.title2.bold())

                Text(String(localized: "wishlists.follow.by \(wishlist.userName)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let description = wishlist.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 16) {
                    Label(
                        "\(wishlist.items?.count ?? 0)",
                        systemImage: "gift"
                    )

                    if let dueDate = wishlist.dueDate {
                        Label(
                            dueDate,
                            systemImage: "calendar"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.appSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            // Follow Button
            Button {
                Task {
                    await followWishlist()
                }
            } label: {
                HStack {
                    if isFollowing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle")
                        Text(String(localized: "wishlists.follow.button"))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isFollowing)
        }
        .padding()
    }

    private func loadWishlist() async {
        isLoading = true
        error = nil

        guard let apiClient = apiClient else {
            error = .unknown
            isLoading = false
            return
        }

        do {
            wishlist = try await apiClient.getWishlistByToken(token)
        } catch {
            self.error = AppError(from: error)
        }

        isLoading = false
    }

    private func followWishlist() async {
        guard let apiClient = apiClient else { return }

        isFollowing = true

        do {
            let dto = try await apiClient.followWishlist(token: token)
            try dataController?.saveWishlist(dto)
            dismiss()
        } catch {
            self.error = AppError(from: error)
        }

        isFollowing = false
    }
}


// MARK: - Preview

#Preview("Wishlists Navigation") {
    WishlistsNavigationView()
        .withDependencies(DependencyContainer.preview)
}

#Preview("Share Wishlist") {
    ShareWishlistView(
        wishlist: Wishlist(
            id: "1",
            userId: "user1",
            userName: "John",
            name: "Birthday Wishlist",
            sharedToken: "abc123"
        )
    )
}

#Preview("Follow Wishlist") {
    FollowWishlistView(token: "abc123")
        .withDependencies(DependencyContainer.preview)
}
