import SwiftUI

struct CreateWishlistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dataController) private var dataController
    @Environment(\.apiClient) private var apiClient
    @Environment(\.authManager) private var authManager
    @Environment(\.networkMonitor) private var networkMonitor

    @State private var name = ""
    @State private var description = ""
    @State private var dueDate: Date?
    @State private var showDatePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "wishlist.field.name"), text: $name)
                        .textContentType(.none)

                    TextField(
                        String(localized: "wishlist.field.description"),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section {
                    Toggle(isOn: $showDatePicker) {
                        HStack {
                            Label(
                                String(localized: "wishlist.field.dueDate"),
                                systemImage: "calendar"
                            )

                            Spacer()

                            if let date = dueDate, showDatePicker {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if showDatePicker {
                        DatePicker(
                            String(localized: "wishlist.field.selectDate"),
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }
                } footer: {
                    Text(String(localized: "wishlist.dueDate.hint"))
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.appError)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(String(localized: "wishlist.create.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.create")) {
                        Task { await createWishlist() }
                    }
                    .disabled(name.isEmpty || isLoading)
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
        }
    }

    private func createWishlist() async {
        guard !name.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        let userId = authManager?.currentUser?.id ?? ""
        let userName = authManager?.currentUser?.name ?? ""

        do {
            // Create locally first (optimistic)
            let wishlist = try dataController?.createWishlist(
                name: name,
                description: description.isEmpty ? nil : description,
                dueDate: showDatePicker ? dueDate : nil,
                userId: userId,
                userName: userName
            )

            // Sync to server if online
            if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
                let dateFormatter = ISO8601DateFormatter()
                let dueDateString = (showDatePicker && dueDate != nil)
                    ? dateFormatter.string(from: dueDate!)
                    : nil

                let request = CreateWishlistRequest(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    dueDate: dueDateString
                )

                let dto = try await apiClient.createWishlist(request)

                // Update local wishlist with server response
                if let wishlist = wishlist {
                    wishlist.id = dto.id
                    wishlist.sharedToken = dto.sharedToken
                    wishlist.needsSync = false
                    try dataController?.save()
                }
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Edit Wishlist View

struct EditWishlistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dataController) private var dataController
    @Environment(\.apiClient) private var apiClient
    @Environment(\.networkMonitor) private var networkMonitor

    let wishlist: Wishlist

    @State private var name: String
    @State private var description: String
    @State private var dueDate: Date?
    @State private var showDatePicker: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(wishlist: Wishlist) {
        self.wishlist = wishlist
        _name = State(initialValue: wishlist.name)
        _description = State(initialValue: wishlist.wishlistDescription ?? "")
        _dueDate = State(initialValue: wishlist.dueDate)
        _showDatePicker = State(initialValue: wishlist.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "wishlist.field.name"), text: $name)

                    TextField(
                        String(localized: "wishlist.field.description"),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section {
                    Toggle(isOn: $showDatePicker) {
                        HStack {
                            Label(
                                String(localized: "wishlist.field.dueDate"),
                                systemImage: "calendar"
                            )

                            Spacer()

                            if let date = dueDate, showDatePicker {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if showDatePicker {
                        DatePicker(
                            String(localized: "wishlist.field.selectDate"),
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.appError)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(String(localized: "wishlist.edit.title"))
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
                        Task { await updateWishlist() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .interactiveDismissDisabled(isLoading)
        }
    }

    private func updateWishlist() async {
        guard !name.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Update locally first
            try dataController?.updateWishlist(
                wishlist,
                name: name,
                description: description.isEmpty ? nil : description,
                dueDate: showDatePicker ? dueDate : nil
            )

            // Sync to server if online
            if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
                let dateFormatter = ISO8601DateFormatter()
                let dueDateString = (showDatePicker && dueDate != nil)
                    ? dateFormatter.string(from: dueDate!)
                    : nil

                let request = UpdateWishlistRequest(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    dueDate: dueDateString
                )

                let _ = try await apiClient.updateWishlist(id: wishlist.id, request: request)
                wishlist.needsSync = false
                try dataController?.save()
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview("Create Wishlist") {
    CreateWishlistView()
        .withDependencies(DependencyContainer.preview)
}
