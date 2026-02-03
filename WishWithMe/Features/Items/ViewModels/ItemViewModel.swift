import Foundation
import Observation

// MARK: - Item Form Mode

enum ItemFormMode: Sendable {
    case create
    case edit(WishlistItem)

    var title: String {
        switch self {
        case .create:
            return String(localized: "item.add.title")
        case .edit:
            return String(localized: "item.edit.title")
        }
    }

    var submitButtonTitle: String {
        switch self {
        case .create:
            return String(localized: "button.add")
        case .edit:
            return String(localized: "button.save")
        }
    }
}

// MARK: - Currency

struct Currency: Identifiable, Hashable, Sendable {
    let code: String
    let symbol: String
    let name: String

    var id: String { code }

    static let supported: [Currency] = [
        Currency(code: "RUB", symbol: "\u{20BD}", name: "Russian Ruble"),
        Currency(code: "USD", symbol: "$", name: "US Dollar"),
        Currency(code: "EUR", symbol: "\u{20AC}", name: "Euro"),
        Currency(code: "GBP", symbol: "\u{00A3}", name: "British Pound"),
        Currency(code: "CNY", symbol: "\u{00A5}", name: "Chinese Yuan"),
        Currency(code: "KZT", symbol: "\u{20B8}", name: "Kazakhstani Tenge"),
        Currency(code: "UAH", symbol: "\u{20B4}", name: "Ukrainian Hryvnia"),
        Currency(code: "BYN", symbol: "Br", name: "Belarusian Ruble"),
    ]

    static func find(code: String?) -> Currency {
        guard let code = code else { return supported[0] }
        return supported.first { $0.code == code } ?? supported[0]
    }
}

// MARK: - Item View Model

@Observable
@MainActor
final class ItemViewModel {

    // MARK: - Dependencies

    private var apiClient: APIClient?
    private var dataController: DataController?
    private var networkMonitor: NetworkMonitor?
    private weak var wishlist: Wishlist?

    // MARK: - Mode

    let mode: ItemFormMode
    private var originalItem: WishlistItem?

    // MARK: - Form State

    var name: String = ""
    var itemDescription: String = ""
    var url: String = ""
    var priceString: String = ""
    var currency: Currency = Currency.supported[0]
    var imageURL: String = ""
    var priority: Priority?
    var notes: String = ""

    // MARK: - UI State

    private(set) var isLoading: Bool = false
    private(set) var isResolving: Bool = false
    private(set) var error: AppError?
    private(set) var isResolved: Bool = false

    // MARK: - Computed Properties

    var price: Double? {
        let cleaned = priceString
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        return Double(cleaned)
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canResolveURL: Bool {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Basic URL validation
        if let url = URL(string: trimmed),
           let scheme = url.scheme,
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            return true
        }

        // Try adding https://
        if let url = URL(string: "https://\(trimmed)"),
           url.host != nil {
            return true
        }

        return false
    }

    var detectedMarketplace: Marketplace? {
        guard !url.isEmpty else { return nil }
        return detectMarketplace(from: url)
    }

    var hasChanges: Bool {
        guard case .edit(let item) = mode else {
            return !name.isEmpty || !url.isEmpty || !priceString.isEmpty
        }

        return name != item.name ||
               itemDescription != (item.itemDescription ?? "") ||
               url != (item.url ?? "") ||
               priceString != (item.price.map { String($0) } ?? "") ||
               currency.code != (item.currency ?? "RUB") ||
               imageURL != (item.image ?? "") ||
               priority != item.priority ||
               notes != (item.notes ?? "")
    }

    // MARK: - Initialization

    init(mode: ItemFormMode, wishlist: Wishlist? = nil) {
        self.mode = mode
        self.wishlist = wishlist

        if case .edit(let item) = mode {
            self.originalItem = item
            self.name = item.name
            self.itemDescription = item.itemDescription ?? ""
            self.url = item.url ?? ""
            self.priceString = item.price.map { String($0) } ?? ""
            self.currency = Currency.find(code: item.currency)
            self.imageURL = item.image ?? ""
            self.priority = item.priority
            self.notes = item.notes ?? ""
        }
    }

    func setDependencies(
        apiClient: APIClient,
        dataController: DataController,
        networkMonitor: NetworkMonitor
    ) {
        self.apiClient = apiClient
        self.dataController = dataController
        self.networkMonitor = networkMonitor
    }

    func setWishlist(_ wishlist: Wishlist) {
        self.wishlist = wishlist
    }

    // MARK: - URL Resolution

    /// Resolves the URL to auto-populate item details
    func resolveURL() async {
        guard canResolveURL, let apiClient = apiClient else { return }

        isResolving = true
        error = nil

        do {
            // Ensure URL has scheme
            var resolveURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !resolveURL.hasPrefix("http://") && !resolveURL.hasPrefix("https://") {
                resolveURL = "https://\(resolveURL)"
            }

            let response = try await apiClient.resolveItem(url: resolveURL)

            // Auto-populate fields from response
            if let resolvedName = response.name, name.isEmpty {
                name = resolvedName
            }

            if let resolvedDescription = response.description, itemDescription.isEmpty {
                itemDescription = resolvedDescription
            }

            if let resolvedPrice = response.price {
                priceString = String(resolvedPrice)
            }

            if let resolvedCurrency = response.currency {
                currency = Currency.find(code: resolvedCurrency)
            }

            if let resolvedImage = response.image {
                imageURL = resolvedImage
            }

            // Update URL to resolved URL
            url = response.url

            isResolved = true
        } catch {
            self.error = AppError(from: error)
        }

        isResolving = false
    }

    // MARK: - Save

    /// Saves the item (creates or updates based on mode)
    func save() async throws -> WishlistItem? {
        guard isFormValid else { return nil }
        guard let dataController = dataController else {
            throw APIError.unknown
        }

        isLoading = true
        defer { isLoading = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .create:
            return try await createItem(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                url: trimmedURL.isEmpty ? nil : normalizeURL(trimmedURL),
                price: price,
                currency: currency.code,
                image: trimmedImageURL.isEmpty ? nil : trimmedImageURL,
                priority: priority,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )

        case .edit(let item):
            try await updateItem(
                item,
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                url: trimmedURL.isEmpty ? nil : normalizeURL(trimmedURL),
                price: price,
                currency: currency.code,
                image: trimmedImageURL.isEmpty ? nil : trimmedImageURL,
                priority: priority,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            return item
        }
    }

    private func createItem(
        name: String,
        description: String?,
        url: String?,
        price: Double?,
        currency: String?,
        image: String?,
        priority: Priority?,
        notes: String?
    ) async throws -> WishlistItem {
        guard let wishlist = wishlist, let dataController = dataController else {
            throw APIError.unknown
        }

        // Create locally first
        let item = try dataController.addItem(
            to: wishlist,
            name: name,
            description: description,
            url: url,
            price: price,
            currency: currency,
            image: image,
            priority: priority,
            notes: notes
        )

        // Sync to server if online
        if networkMonitor?.isConnected ?? false, let apiClient = apiClient {
            let request = AddItemRequest(
                name: name,
                description: description,
                url: url,
                price: price,
                currency: currency,
                image: image,
                priority: priority?.rawValue,
                notes: notes
            )

            do {
                let dto = try await apiClient.addItem(wishlistId: wishlist.id, request: request)

                // Update with server response
                if let newItem = dto.items?.first(where: { $0.name == name }) {
                    item.id = newItem.id
                }
                item.needsSync = false
                try dataController.save()
            } catch {
                // Keep local version, will sync later
                item.needsSync = true
            }
        }

        return item
    }

    private func updateItem(
        _ item: WishlistItem,
        name: String,
        description: String?,
        url: String?,
        price: Double?,
        currency: String?,
        image: String?,
        priority: Priority?,
        notes: String?
    ) async throws {
        guard let dataController = dataController else {
            throw APIError.unknown
        }

        // Update locally first
        try dataController.updateItem(
            item,
            name: name,
            description: description,
            url: url,
            price: price,
            currency: currency,
            image: image,
            bought: nil,
            priority: priority,
            notes: notes
        )

        // Sync to server if online
        if let wishlist = item.wishlist,
           networkMonitor?.isConnected ?? false,
           let apiClient = apiClient {
            let request = UpdateItemRequest(
                name: name,
                description: description,
                url: url,
                price: price,
                currency: currency,
                image: image,
                bought: nil,
                priority: priority?.rawValue,
                notes: notes
            )

            do {
                let _ = try await apiClient.updateItem(
                    wishlistId: wishlist.id,
                    itemId: item.id,
                    request: request
                )
                item.needsSync = false
                try dataController.save()
            } catch {
                // Keep local version, will sync later
                item.needsSync = true
            }
        }
    }

    // MARK: - Delete

    /// Deletes the item (only for edit mode)
    func delete() async throws {
        guard case .edit(let item) = mode,
              let dataController = dataController else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Mark for deletion locally
        try dataController.markItemForDeletion(item)

        // Sync to server if online
        if let wishlist = item.wishlist,
           networkMonitor?.isConnected ?? false,
           let apiClient = apiClient {
            do {
                try await apiClient.deleteItem(wishlistId: wishlist.id, itemId: item.id)
                try dataController.deleteItem(item)
            } catch {
                // Keep local deletion mark, will sync later
            }
        }
    }

    // MARK: - Helpers

    private func detectMarketplace(from urlString: String) -> Marketplace? {
        let lowercased = urlString.lowercased()

        if lowercased.contains("ozon.ru") || lowercased.contains("ozon.") {
            return .ozon
        } else if lowercased.contains("wildberries.ru") || lowercased.contains("wb.ru") {
            return .wildberries
        } else if lowercased.contains("market.yandex") || lowercased.contains("beru.ru") {
            return .yandexMarket
        } else if lowercased.contains("aliexpress") {
            return .aliexpress
        } else if lowercased.contains("amazon") {
            return .amazon
        }

        return nil
    }

    private func normalizeURL(_ urlString: String) -> String {
        var normalized = urlString

        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://\(normalized)"
        }

        return normalized
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }

    // MARK: - Reset

    func reset() {
        if case .edit(let item) = mode {
            name = item.name
            itemDescription = item.itemDescription ?? ""
            url = item.url ?? ""
            priceString = item.price.map { String($0) } ?? ""
            currency = Currency.find(code: item.currency)
            imageURL = item.image ?? ""
            priority = item.priority
            notes = item.notes ?? ""
        } else {
            name = ""
            itemDescription = ""
            url = ""
            priceString = ""
            currency = Currency.supported[0]
            imageURL = ""
            priority = nil
            notes = ""
        }

        isResolved = false
        error = nil
    }
}
