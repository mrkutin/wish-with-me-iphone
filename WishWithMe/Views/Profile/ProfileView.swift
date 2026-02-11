import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    let syncEngine: SyncEngine?

    @State private var viewModel: ProfileViewModel?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto: Bool = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                profileContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if viewModel == nil {
                let vm = ProfileViewModel(
                    modelContext: modelContext,
                    syncEngine: syncEngine,
                    authManager: authManager
                )
                viewModel = vm
            }
            viewModel?.syncEngine = syncEngine
            viewModel?.loadProfile()
        }
    }

    @ViewBuilder
    private func profileContent(viewModel: ProfileViewModel) -> some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    avatarView(viewModel: viewModel)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Name", text: Bindable(viewModel).name)
                    .textContentType(.name)

                TextField("Bio", text: Bindable(viewModel).bio, axis: .vertical)
                    .lineLimit(3...6)

                HStack {
                    Text("wishwith.me/u/")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    TextField("handle", text: Bindable(viewModel).publicUrlSlug)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                if let slugError = viewModel.slugError {
                    Text(slugError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                TextField("Birthday (YYYY-MM-DD)", text: Bindable(viewModel).birthday)
                    .keyboardType(.numbersAndPunctuation)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            if let success = viewModel.successMessage {
                Section {
                    Text(success)
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    viewModel.saveProfile()
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!viewModel.canSave)
                .accessibilityLabel("Save profile changes")
            }

            Section {
                NavigationLink("Settings") {
                    SettingsView(syncEngine: syncEngine)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        try? await authManager.logout()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Log Out")
                        Spacer()
                    }
                }
                .accessibilityLabel("Log out of your account")
            }
        }
    }

    @ViewBuilder
    private func avatarView(viewModel: ProfileViewModel) -> some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                AvatarView(
                    name: viewModel.name,
                    avatarBase64: viewModel.avatarBase64,
                    size: 80
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.brandPrimary)
                        .background(Circle().fill(.background).padding(2))
                }
            }
            .accessibilityLabel("Change profile photo")
            .onChange(of: selectedPhoto) { _, newPhoto in
                guard let newPhoto else { return }
                isLoadingPhoto = true
                Task {
                    defer { isLoadingPhoto = false }
                    guard let data = try? await newPhoto.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else { return }
                    let resized = resizeImage(uiImage, maxSize: 200)
                    guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { return }
                    let base64 = "data:image/jpeg;base64," + jpegData.base64EncodedString()
                    viewModel.updateAvatar(base64)
                }
            }

            if isLoadingPhoto {
                ProgressView()
            }

            Text(viewModel.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        if ratio >= 1.0 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
