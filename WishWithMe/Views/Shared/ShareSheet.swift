import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct ShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let syncEngine: SyncEngine?
    let wishlistId: String

    @State private var viewModel: ShareViewModel?
    @State private var showCreateOptions: Bool = false
    @State private var shareToRevoke: Share?
    @State private var showRevokeAlert: Bool = false
    @State private var copiedShareId: String?
    @State private var qrShareToken: String?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    content(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Share Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close share sheet")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateOptions = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel?.isCreating == true)
                    .accessibilityLabel("Create new share link")
                }
            }
            .confirmationDialog("Create Share Link", isPresented: $showCreateOptions) {
                Button("View & Mark (recommended)") {
                    Task {
                        HapticManager.impact(.light)
                        await viewModel?.createShareLink(linkType: "mark")
                    }
                }
                Button("View Only") {
                    Task {
                        HapticManager.impact(.light)
                        await viewModel?.createShareLink(linkType: "view")
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose the permissions for this link")
            }
            .alert("Revoke Link", isPresented: $showRevokeAlert) {
                Button("Cancel", role: .cancel) {
                    shareToRevoke = nil
                }
                Button("Revoke", role: .destructive) {
                    if let share = shareToRevoke {
                        Task {
                            await viewModel?.revokeShareLink(share)
                        }
                    }
                    shareToRevoke = nil
                }
            } message: {
                Text("This link will stop working. People who already have access will keep it.")
            }
            .sheet(isPresented: Binding(
                get: { qrShareToken != nil },
                set: { if !$0 { qrShareToken = nil } }
            )) {
                if let token = qrShareToken {
                    QRCodeSheet(shareURL: "https://wishwith.me/s/\(token)")
                }
            }
            .onAppear {
                if viewModel == nil {
                    let vm = ShareViewModel(
                        modelContext: modelContext,
                        syncEngine: syncEngine,
                        wishlistId: wishlistId
                    )
                    viewModel = vm
                }
                viewModel?.syncEngine = syncEngine
                viewModel?.loadShares()
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: ShareViewModel) -> some View {
        if viewModel.isCreating {
            VStack(spacing: 16) {
                ProgressView()
                Text("Creating share link...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.shares.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("No share links yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Create a link to share this wishlist with friends and family")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showCreateOptions = true
                } label: {
                    Label("Create Link", systemImage: "link.badge.plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
                Spacer()
            }
            .padding()
        } else {
            List {
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                Section {
                    ForEach(viewModel.shares, id: \.id) { share in
                        shareLinkRow(share: share, viewModel: viewModel)
                    }
                } footer: {
                    Text("People with the link can access your wishlist")
                }
            }
        }
    }

    private func shareLinkRow(share: Share, viewModel: ShareViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: share.linkType == "mark" ? "eye.fill" : "eye")
                    .foregroundStyle(Color.brandPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(share.linkType == "mark" ? "View & Mark" : "View Only")
                        .font(.body)
                        .fontWeight(.medium)

                    if share.grantedUsers.count > 0 {
                        Text("\(share.grantedUsers.count) people joined")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    let url = viewModel.shareLinkURL(share)
                    UIPasteboard.general.string = url
                    copiedShareId = share.id
                    HapticManager.notification(.success)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if copiedShareId == share.id {
                            copiedShareId = nil
                        }
                    }
                } label: {
                    Image(systemName: copiedShareId == share.id ? "checkmark" : "doc.on.doc")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(copiedShareId == share.id ? .green : Color.brandPrimary)
                .accessibilityLabel("Copy share link to clipboard")

                Button {
                    let url = viewModel.shareLinkURL(share)
                    let activityVC = UIActivityViewController(
                        activityItems: [URL(string: url) ?? url],
                        applicationActivities: nil
                    )
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        var topVC = rootVC
                        while let presented = topVC.presentedViewController {
                            topVC = presented
                        }
                        topVC.present(activityVC, animated: true)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Share link")

                Button {
                    qrShareToken = share.token
                } label: {
                    Image(systemName: "qrcode")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Show QR code")

                Spacer()

                Button {
                    shareToRevoke = share
                    showRevokeAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Revoke share link")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct QRCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shareURL: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let image = generateQRCode(for: shareURL) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                }

                Text("Scan this code to access the wishlist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateQRCode(for string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        let scale = 250.0 / ciImage.extent.size.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
