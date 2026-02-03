import Foundation
import SwiftData

// MARK: - Priority Enum

enum Priority: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return String(localized: "priority.low")
        case .medium: return String(localized: "priority.medium")
        case .high: return String(localized: "priority.high")
        }
    }

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

// MARK: - Wishlist Item DTO (API Response)

struct WishlistItemDTO: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let url: String?
    let price: Double?
    let currency: String?
    let image: String?
    let bought: Bool?
    let priority: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case description
        case url
        case price
        case currency
        case image
        case bought
        case priority
        case notes
        case createdAt
        case updatedAt
    }
}

// MARK: - Item Requests

struct AddItemRequest: Codable, Sendable {
    let name: String
    let description: String?
    let url: String?
    let price: Double?
    let currency: String?
    let image: String?
    let priority: String?
    let notes: String?
}

struct UpdateItemRequest: Codable, Sendable {
    let name: String?
    let description: String?
    let url: String?
    let price: Double?
    let currency: String?
    let image: String?
    let bought: Bool?
    let priority: String?
    let notes: String?
}

struct ResolveItemRequest: Codable, Sendable {
    let url: String
}

struct ResolveItemResponse: Codable, Sendable {
    let name: String?
    let description: String?
    let price: Double?
    let currency: String?
    let image: String?
    let url: String
}

// MARK: - Wishlist Item Model (SwiftData)

@Model
final class WishlistItem {
    @Attribute(.unique) var id: String
    var name: String
    var itemDescription: String?
    var url: String?
    var price: Double?
    var currency: String?
    var image: String?
    var bought: Bool
    var priorityRawValue: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    // Relationship
    var wishlist: Wishlist?

    // Sync metadata
    var needsSync: Bool
    var pendingDeletion: Bool

    // Computed property for priority
    var priority: Priority? {
        get {
            guard let rawValue = priorityRawValue else { return nil }
            return Priority(rawValue: rawValue)
        }
        set {
            priorityRawValue = newValue?.rawValue
        }
    }

    // Computed property for marketplace detection
    var marketplace: Marketplace? {
        guard let url = url?.lowercased() else { return nil }

        if url.contains("ozon.ru") || url.contains("ozon.") {
            return .ozon
        } else if url.contains("wildberries.ru") || url.contains("wb.ru") {
            return .wildberries
        } else if url.contains("market.yandex") || url.contains("beru.ru") {
            return .yandexMarket
        } else if url.contains("aliexpress") {
            return .aliexpress
        } else if url.contains("amazon") {
            return .amazon
        }

        return nil
    }

    init(
        id: String,
        name: String,
        itemDescription: String? = nil,
        url: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        image: String? = nil,
        bought: Bool = false,
        priority: Priority? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        needsSync: Bool = false,
        pendingDeletion: Bool = false
    ) {
        self.id = id
        self.name = name
        self.itemDescription = itemDescription
        self.url = url
        self.price = price
        self.currency = currency
        self.image = image
        self.bought = bought
        self.priorityRawValue = priority?.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.pendingDeletion = pendingDeletion
    }

    convenience init(from dto: WishlistItemDTO) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdAt = dto.createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedAt = dto.updatedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let priority = dto.priority.flatMap { Priority(rawValue: $0) }

        self.init(
            id: dto.id,
            name: dto.name,
            itemDescription: dto.description,
            url: dto.url,
            price: dto.price,
            currency: dto.currency,
            image: dto.image,
            bought: dto.bought ?? false,
            priority: priority,
            notes: dto.notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Marketplace Enum

enum Marketplace: String, CaseIterable, Sendable {
    case ozon
    case wildberries
    case yandexMarket
    case aliexpress
    case amazon

    var displayName: String {
        switch self {
        case .ozon: return "Ozon"
        case .wildberries: return "Wildberries"
        case .yandexMarket: return "Yandex Market"
        case .aliexpress: return "AliExpress"
        case .amazon: return "Amazon"
        }
    }

    var iconName: String {
        switch self {
        case .ozon: return "cart.fill"
        case .wildberries: return "bag.fill"
        case .yandexMarket: return "basket.fill"
        case .aliexpress: return "shippingbox.fill"
        case .amazon: return "box.truck.fill"
        }
    }
}
