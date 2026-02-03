import SwiftUI

// MARK: - Share Wishlist Sheet

struct ShareWishlistSheet: View {
    @Environment(\.dismiss) private var dismiss

    let wishlist: Wishlist

    @State private var isCopied = false
    @State private var selectedTab: ShareTab = .link

    private var shareURL: URL? {
        SharingViewModel.generateShareURL(for: wishlist)
    }

    enum ShareTab: String, CaseIterable {
        case link
        case qrCode

        var title: String {
            switch self {
            case .link: return String(localized: "share.tab.link")
            case .qrCode: return String(localized: "share.tab.qrcode")
            }
        }

        var icon: String {
            switch self {
            case .link: return "link"
            case .qrCode: return "qrcode"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("", selection: $selectedTab) {
                    ForEach(ShareTab.allCases, id: \.self) { tab in
                        Label(tab.title, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Wishlist info header
                        wishlistHeader

                        Divider()
                            .padding(.horizontal)

                        // Tab content
                        switch selectedTab {
                        case .link:
                            linkContent
                        case .qrCode:
                            qrCodeContent
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
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

    // MARK: - Wishlist Header

    private var wishlistHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.appPrimary)

            Text(wishlist.name)
                .font(.title3.bold())

            if let description = wishlist.wishlistDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Label(
                    "\(wishlist.items.filter { !$0.pendingDeletion }.count) \(String(localized: "share.items"))",
                    systemImage: "gift"
                )

                if !wishlist.sharedWith.isEmpty {
                    Label(
                        "\(wishlist.sharedWith.count) \(String(localized: "share.followers"))",
                        systemImage: "person.2"
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Link Content

    private var linkContent: some View {
        VStack(spacing: 20) {
            // Share description
            VStack(spacing: 8) {
                Text(String(localized: "share.link.title"))
                    .font(.headline)

                Text(String(localized: "share.link.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Link display
            if let url = shareURL {
                VStack(spacing: 16) {
                    Text(url.absoluteString)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.appTertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Action buttons
                    HStack(spacing: 16) {
                        // Copy button
                        Button {
                            copyToClipboard()
                        } label: {
                            Label(
                                isCopied
                                    ? String(localized: "share.linkCopied")
                                    : String(localized: "share.copyLink"),
                                systemImage: isCopied ? "checkmark" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isCopied ? Color.appSuccess : Color.appPrimary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // System share button
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

            // Info text
            infoFooter
        }
        .padding(.horizontal)
    }

    // MARK: - QR Code Content

    private var qrCodeContent: some View {
        VStack(spacing: 20) {
            // QR Code description
            VStack(spacing: 8) {
                Text(String(localized: "share.qrcode.title"))
                    .font(.headline)

                Text(String(localized: "share.qrcode.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // QR Code
            if let url = shareURL {
                QRCodeCardView(
                    content: url.absoluteString,
                    title: nil,
                    size: 200
                )
            }

            // Info text
            infoFooter
        }
        .padding(.horizontal)
    }

    // MARK: - Info Footer

    private var infoFooter: some View {
        VStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            Text(String(localized: "share.info"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    // MARK: - Actions

    private func copyToClipboard() {
        guard let url = shareURL else { return }
        UIPasteboard.general.string = url.absoluteString

        withAnimation {
            isCopied = true
        }

        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Share Wishlist Sheet") {
    ShareWishlistSheet(
        wishlist: Wishlist(
            id: "1",
            userId: "user1",
            userName: "John",
            name: "Birthday Wishlist",
            wishlistDescription: "Things I'd love to receive for my birthday!",
            sharedToken: "abc123def456"
        )
    )
}
