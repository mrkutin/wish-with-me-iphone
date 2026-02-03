import SwiftUI

struct CreateWishlistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var apiClient
    @Environment(\.dataController) private var dataController
    @Environment(\.authManager) private var authManager
    @Environment(\.networkMonitor) private var networkMonitor

    var onWishlistCreated: ((Wishlist) -> Void)?

    @State private var name = ""
    @State private var description = ""
    @State private var dueDate: Date?
    @State private var showDatePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var viewModel: WishlistsViewModel?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "wishlist.field.name"), text: $name)
                        .textContentType(.none)
                        .accessibilityLabel(String(localized: "wishlist.field.name"))

                    TextField(
                        String(localized: "wishlist.field.description"),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .accessibilityLabel(String(localized: "wishlist.field.description"))
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
                            .foregroundStyle(Color.appError)
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .interactiveDismissDisabled(isLoading)
            .overlay {
                if isLoading {
                    LoadingOverlay()
                }
            }
            .onAppear {
                setupViewModel()
            }
        }
    }

    private func setupViewModel() {
        if let apiClient = apiClient,
           let dataController = dataController,
           let networkMonitor = networkMonitor,
           let authManager = authManager {
            let vm = WishlistsViewModel()
            vm.setDependencies(
                apiClient: apiClient,
                dataController: dataController,
                networkMonitor: networkMonitor,
                authManager: authManager
            )
            viewModel = vm
        }
    }

    private func createWishlist() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let wishlist = try await viewModel?.createWishlist(
                name: trimmedName,
                description: description.isEmpty ? nil : description,
                dueDate: showDatePicker ? dueDate : nil
            )

            if let wishlist = wishlist {
                onWishlistCreated?(wishlist)
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
    @Environment(\.apiClient) private var apiClient
    @Environment(\.dataController) private var dataController
    @Environment(\.authManager) private var authManager
    @Environment(\.networkMonitor) private var networkMonitor

    let wishlist: Wishlist
    var onWishlistUpdated: (() -> Void)?

    @State private var name: String
    @State private var description: String
    @State private var dueDate: Date?
    @State private var showDatePicker: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var viewModel: WishlistsViewModel?

    init(wishlist: Wishlist, onWishlistUpdated: (() -> Void)? = nil) {
        self.wishlist = wishlist
        self.onWishlistUpdated = onWishlistUpdated
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
                        .accessibilityLabel(String(localized: "wishlist.field.name"))

                    TextField(
                        String(localized: "wishlist.field.description"),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .accessibilityLabel(String(localized: "wishlist.field.description"))
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
                            .foregroundStyle(Color.appError)
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || !hasChanges)
                }
            }
            .interactiveDismissDisabled(isLoading)
            .overlay {
                if isLoading {
                    LoadingOverlay()
                }
            }
            .onAppear {
                setupViewModel()
            }
        }
    }

    private var hasChanges: Bool {
        name != wishlist.name ||
        description != (wishlist.wishlistDescription ?? "") ||
        dueDate != wishlist.dueDate ||
        showDatePicker != (wishlist.dueDate != nil)
    }

    private func setupViewModel() {
        if let apiClient = apiClient,
           let dataController = dataController,
           let networkMonitor = networkMonitor,
           let authManager = authManager {
            let vm = WishlistsViewModel()
            vm.setDependencies(
                apiClient: apiClient,
                dataController: dataController,
                networkMonitor: networkMonitor,
                authManager: authManager
            )
            viewModel = vm
        }
    }

    private func updateWishlist() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await viewModel?.updateWishlist(
                wishlist,
                name: trimmedName,
                description: description.isEmpty ? nil : description,
                dueDate: showDatePicker ? dueDate : nil
            )

            onWishlistUpdated?()
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

#Preview("Edit Wishlist") {
    EditWishlistView(
        wishlist: Wishlist(
            id: "1",
            userId: "user1",
            userName: "John",
            name: "Birthday Wishlist",
            wishlistDescription: "My birthday gift ideas",
            dueDate: Date().addingTimeInterval(86400 * 30),
            sharedToken: "token123"
        )
    )
    .withDependencies(DependencyContainer.preview)
}
