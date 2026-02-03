import SwiftUI

// MARK: - Follow Wishlist View

struct FollowWishlistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var apiClient
    @Environment(\.dataController) private var dataController
    @Environment(\.networkMonitor) private var networkMonitor

    let token: String

    @State private var viewModel = SharingViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if let wishlist = viewModel.sharedWishlist {
                    wishlistPreview(wishlist)
                } else {
                    // Initial state - show loading
                    loadingView
                }
            }
            .navigationTitle(String(localized: "follow.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                }
            }
            .task {
                setupViewModel()
                await viewModel.loadWishlist(token: token)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(String(localized: "follow.loading"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ error: AppError) -> some View {
        ContentUnavailableView {
            Label(error.title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            if error.isRetryable {
                Button(String(localized: "button.retry")) {
                    Task {
                        await viewModel.loadWishlist(token: token)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Wishlist Preview

    private func wishlistPreview(_ wishlist: WishlistDTO) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with icon
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.appPrimary.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "gift.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.appPrimary)
                    }

                    VStack(spacing: 8) {
                        Text(wishlist.name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        HStack(spacing: 4) {
                            Text(String(localized: "follow.by"))
                            Text(wishlist.userName)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)

                // Description
                if let description = wishlist.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Stats
                HStack(spacing: 24) {
                    statItem(
                        icon: "gift",
                        value: "\(wishlist.items?.count ?? 0)",
                        label: String(localized: "follow.items")
                    )

                    if let dueDate = wishlist.dueDate {
                        statItem(
                            icon: "calendar",
                            value: formatDate(dueDate),
                            label: String(localized: "follow.dueDate")
                        )
                    }

                    if let sharedWith = wishlist.sharedWith, !sharedWith.isEmpty {
                        statItem(
                            icon: "person.2",
                            value: "\(sharedWith.count)",
                            label: String(localized: "follow.followers")
                        )
                    }
                }
                .padding()
                .background(Color.appSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Items preview (first 3)
                if let items = wishlist.items, !items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "follow.itemsPreview"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(Array(items.prefix(3)), id: \.id) { item in
                            itemPreviewRow(item)
                        }

                        if items.count > 3 {
                            Text(String(localized: "follow.moreItems \(items.count - 3)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.appSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Spacer(minLength: 24)

                // Follow button
                VStack(spacing: 12) {
                    Button {
                        Task {
                            let success = await viewModel.followWishlist(token: token)
                            if success {
                                // Provide haptic feedback
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isFollowing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(String(localized: "follow.button"))
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.isFollowing)

                    Text(String(localized: "follow.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }

    // MARK: - Helper Views

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.appPrimary)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }

    private func itemPreviewRow(_ item: WishlistItemDTO) -> some View {
        HStack(spacing: 12) {
            // Item icon or image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appTertiaryBackground)
                    .frame(width: 44, height: 44)

                if item.bought ?? false {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "gift")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)

                if let price = item.price {
                    Text(formatPrice(price, currency: item.currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.bought ?? false {
                Text(String(localized: "item.status.bought"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appSuccess.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Setup

    private func setupViewModel() {
        if let apiClient = apiClient,
           let dataController = dataController,
           let networkMonitor = networkMonitor {
            viewModel.setDependencies(
                apiClient: apiClient,
                dataController: dataController,
                networkMonitor: networkMonitor
            )
        }
    }

    // MARK: - Formatting

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        return dateString
    }

    private func formatPrice(_ price: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
}

// MARK: - Preview

#Preview("Follow Wishlist") {
    FollowWishlistView(token: "abc123")
        .withDependencies(DependencyContainer.preview)
}
