import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authManager) private var authManager

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "profile.edit.info")) {
                    TextField(String(localized: "profile.field.name"), text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField(String(localized: "profile.field.email"), text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        // TODO: Navigate to change password
                    } label: {
                        Text(String(localized: "profile.changePassword"))
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.appError)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(String(localized: "profile.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.save")) {
                        Task { await saveProfile() }
                    }
                    .disabled(!hasChanges || isLoading)
                }
            }
            .interactiveDismissDisabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .alert(String(localized: "profile.edit.success"), isPresented: $showSuccessMessage) {
                Button(String(localized: "button.ok")) {
                    dismiss()
                }
            }
        }
    }

    private var hasChanges: Bool {
        guard let user = authManager?.currentUser else { return false }
        return name != user.name || email != user.email
    }

    private func loadCurrentProfile() {
        if let user = authManager?.currentUser {
            name = user.name
            email = user.email
        }
    }

    private func saveProfile() async {
        guard hasChanges else { return }

        isLoading = true
        errorMessage = nil

        let nameToUpdate = name != authManager?.currentUser?.name ? name : nil
        let emailToUpdate = email != authManager?.currentUser?.email ? email : nil

        do {
            try await authManager?.updateProfile(
                name: nameToUpdate,
                email: emailToUpdate,
                password: nil
            )
            showSuccessMessage = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview("Edit Profile") {
    EditProfileView()
        .withDependencies(DependencyContainer.preview)
}
