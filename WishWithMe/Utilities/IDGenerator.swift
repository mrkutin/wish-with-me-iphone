import Foundation

enum IDGenerator {
    static func create(type: String) -> String {
        "\(type):\(UUID().uuidString.lowercased())"
    }

    static func extractUUID(_ docId: String) -> String {
        let parts = docId.split(separator: ":")
        return parts.count > 1 ? String(parts[1]) : docId
    }

    static func extractType(_ docId: String) -> String? {
        let parts = docId.split(separator: ":")
        return parts.count > 1 ? String(parts[0]) : nil
    }
}
