import Foundation

// MARK: - AnyCodable (for generic JSON values)

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        // Handle NSNumber before Bool/Int to avoid Foundation's conflation
        // of NSNumber(1) with true. CFBooleanGetTypeID distinguishes real bools.
        if let number = value as? NSNumber, CFBooleanGetTypeID() != CFGetTypeID(number) {
            if number.doubleValue == Double(number.intValue) {
                try container.encode(number.intValue)
            } else {
                try container.encode(number.doubleValue)
            }
            return
        }

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyCodable.init))
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

// MARK: - Push Request/Response

struct SyncPushRequest: Encodable {
    let documents: [[String: AnyCodable]]
}

struct SyncPushResponse: Decodable {
    let conflicts: [SyncConflict]
}

struct SyncConflict: Decodable {
    let documentId: String
    let error: String
    let serverDocument: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case error
        case serverDocument = "server_document"
    }
}

// MARK: - Pull Response

struct SyncPullResponse: Decodable {
    let documents: [[String: AnyCodable]]
}
