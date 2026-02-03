import SwiftUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var apiClient
    @Environment(\.dataController) private var dataController
    @Environment(\.networkMonitor) private var networkMonitor

    let wishlist: Wishlist
    var onItemAdded: ((WishlistItem) -> Void)?

    @State private var viewModel: ItemViewModel

    init(wishlist: Wishlist, onItemAdded: ((WishlistItem) -> Void)? = nil) {
        self.wishlist = wishlist
        self.onItemAdded = onItemAdded
        _viewModel = State(initialValue: ItemViewModel(mode: .create, wishlist: wishlist))
    }

    var body: some View {
        NavigationStack {
            Form {
                // URL Section
                urlSection

                // Basic Info Section
                basicInfoSection

                // Price Section
                priceSection

                // Details Section
                detailsSection

                // Error Section
                if let error = viewModel.error {
                    Section {
                        Text(error.message)
                            .foregroundStyle(Color.appError)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(viewModel.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.mode.submitButtonTitle) {
                        Task { await saveItem() }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }
            }
            .interactiveDismissDisabled(viewModel.isLoading || viewModel.hasChanges)
            .overlay {
                if viewModel.isLoading {
                    LoadingOverlay()
                }
            }
            .onAppear {
                setupDependencies()
            }
        }
    }

    // MARK: - URL Section

    private var urlSection: some View {
        Section {
            HStack {
                TextField(String(localized: "item.field.url"), text: $viewModel.url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textContentType(.URL)

                if viewModel.isResolving {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if viewModel.canResolveURL {
                    Button {
                        Task { await viewModel.resolveURL() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.appPrimary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let marketplace = viewModel.detectedMarketplace {
                HStack {
                    MarketplaceBadge(marketplace: marketplace)

                    if viewModel.isResolved {
                        Spacer()

                        Label(
                            String(localized: "item.resolved"),
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Color.appSuccess)
                    }
                }
            }
        } header: {
            Text(String(localized: "item.section.url"))
        } footer: {
            Text(String(localized: "item.url.hint"))
        }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        Section {
            TextField(String(localized: "item.field.name"), text: $viewModel.name)

            TextField(
                String(localized: "item.field.description"),
                text: $viewModel.itemDescription,
                axis: .vertical
            )
            .lineLimit(2...4)
        } header: {
            Text(String(localized: "item.section.basicInfo"))
        }
    }

    // MARK: - Price Section

    private var priceSection: some View {
        Section {
            HStack {
                TextField(String(localized: "item.field.price"), text: $viewModel.priceString)
                    .keyboardType(.decimalPad)

                Picker("", selection: $viewModel.currency) {
                    ForEach(Currency.supported) { currency in
                        Text("\(currency.symbol) \(currency.code)")
                            .tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        } header: {
            Text(String(localized: "item.section.price"))
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            Picker(String(localized: "item.field.priority"), selection: $viewModel.priority) {
                Text(String(localized: "priority.none")).tag(Priority?.none)
                ForEach(Priority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(Priority?.some(priority))
                }
            }

            TextField(
                String(localized: "item.field.notes"),
                text: $viewModel.notes,
                axis: .vertical
            )
            .lineLimit(2...4)

            // Image URL (optional, shown if resolved or manually entered)
            if !viewModel.imageURL.isEmpty || viewModel.isResolved {
                TextField(String(localized: "item.field.imageURL"), text: $viewModel.imageURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                // Image Preview
                if let url = URL(string: viewModel.imageURL), !viewModel.imageURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.appSecondaryBackground)
                                .frame(height: 100)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 150)
                        case .failure:
                            Rectangle()
                                .fill(Color.appSecondaryBackground)
                                .frame(height: 100)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        } header: {
            Text(String(localized: "item.section.details"))
        }
    }

    // MARK: - Actions

    private func setupDependencies() {
        if let apiClient = apiClient,
           let dataController = dataController,
           let networkMonitor = networkMonitor {
            viewModel.setDependencies(
                apiClient: apiClient,
                dataController: dataController,
                networkMonitor: networkMonitor
            )
        }
        viewModel.setWishlist(wishlist)
    }

    private func saveItem() async {
        do {
            if let item = try await viewModel.save() {
                onItemAdded?(item)
                dismiss()
            }
        } catch {
            // Error is already handled by viewModel
        }
    }
}

// MARK: - Edit Item Sheet

struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var apiClient
    @Environment(\.dataController) private var dataController
    @Environment(\.networkMonitor) private var networkMonitor

    let item: WishlistItem
    var onItemUpdated: (() -> Void)?
    var onItemDeleted: (() -> Void)?

    @State private var viewModel: ItemViewModel
    @State private var showDeleteConfirmation = false

    init(item: WishlistItem, onItemUpdated: (() -> Void)? = nil, onItemDeleted: (() -> Void)? = nil) {
        self.item = item
        self.onItemUpdated = onItemUpdated
        self.onItemDeleted = onItemDeleted
        _viewModel = State(initialValue: ItemViewModel(mode: .edit(item)))
    }

    var body: some View {
        NavigationStack {
            Form {
                // URL Section
                urlSection

                // Basic Info Section
                basicInfoSection

                // Price Section
                priceSection

                // Details Section
                detailsSection

                // Delete Section
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label(String(localized: "item.delete"), systemImage: "trash")
                            Spacer()
                        }
                    }
                }

                // Error Section
                if let error = viewModel.error {
                    Section {
                        Text(error.message)
                            .foregroundStyle(Color.appError)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(viewModel.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.mode.submitButtonTitle) {
                        Task { await saveItem() }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading || !viewModel.hasChanges)
                }
            }
            .interactiveDismissDisabled(viewModel.isLoading || viewModel.hasChanges)
            .overlay {
                if viewModel.isLoading {
                    LoadingOverlay()
                }
            }
            .confirmationDialog(
                String(localized: "item.delete.title"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "button.delete"), role: .destructive) {
                    Task { await deleteItem() }
                }
            } message: {
                Text(String(localized: "item.delete.message"))
            }
            .onAppear {
                setupDependencies()
            }
        }
    }

    // MARK: - URL Section

    private var urlSection: some View {
        Section {
            HStack {
                TextField(String(localized: "item.field.url"), text: $viewModel.url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textContentType(.URL)

                if viewModel.isResolving {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if viewModel.canResolveURL {
                    Button {
                        Task { await viewModel.resolveURL() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.appPrimary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let marketplace = viewModel.detectedMarketplace {
                MarketplaceBadge(marketplace: marketplace)
            }
        } header: {
            Text(String(localized: "item.section.url"))
        }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        Section {
            TextField(String(localized: "item.field.name"), text: $viewModel.name)

            TextField(
                String(localized: "item.field.description"),
                text: $viewModel.itemDescription,
                axis: .vertical
            )
            .lineLimit(2...4)
        } header: {
            Text(String(localized: "item.section.basicInfo"))
        }
    }

    // MARK: - Price Section

    private var priceSection: some View {
        Section {
            HStack {
                TextField(String(localized: "item.field.price"), text: $viewModel.priceString)
                    .keyboardType(.decimalPad)

                Picker("", selection: $viewModel.currency) {
                    ForEach(Currency.supported) { currency in
                        Text("\(currency.symbol) \(currency.code)")
                            .tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        } header: {
            Text(String(localized: "item.section.price"))
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            Picker(String(localized: "item.field.priority"), selection: $viewModel.priority) {
                Text(String(localized: "priority.none")).tag(Priority?.none)
                ForEach(Priority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(Priority?.some(priority))
                }
            }

            TextField(
                String(localized: "item.field.notes"),
                text: $viewModel.notes,
                axis: .vertical
            )
            .lineLimit(2...4)

            TextField(String(localized: "item.field.imageURL"), text: $viewModel.imageURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            // Image Preview
            if let url = URL(string: viewModel.imageURL), !viewModel.imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.appSecondaryBackground)
                            .frame(height: 100)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 150)
                    case .failure:
                        Rectangle()
                            .fill(Color.appSecondaryBackground)
                            .frame(height: 100)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } header: {
            Text(String(localized: "item.section.details"))
        }
    }

    // MARK: - Actions

    private func setupDependencies() {
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

    private func saveItem() async {
        do {
            if let _ = try await viewModel.save() {
                onItemUpdated?()
                dismiss()
            }
        } catch {
            // Error is already handled by viewModel
        }
    }

    private func deleteItem() async {
        do {
            try await viewModel.delete()
            onItemDeleted?()
            dismiss()
        } catch {
            // Error is already handled by viewModel
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}

// MARK: - Preview

#Preview("Add Item") {
    AddItemSheet(
        wishlist: Wishlist(
            id: "1",
            userId: "user1",
            userName: "John",
            name: "Birthday Wishlist",
            sharedToken: "token123"
        )
    )
    .withDependencies(DependencyContainer.preview)
}

#Preview("Edit Item") {
    EditItemSheet(
        item: WishlistItem(
            id: "1",
            name: "Apple AirPods Pro",
            itemDescription: "Wireless earbuds",
            url: "https://ozon.ru/product/airpods",
            price: 24999,
            currency: "RUB",
            priority: .high
        )
    )
    .withDependencies(DependencyContainer.preview)
}
