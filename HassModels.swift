import Foundation

enum WebSocketMessageType {
    case authRequired
    case authOk
    case event
    case result
    case unknown
}

public struct HAContext: Codable {
    let id: String
    let parentId: String?
    let userId: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case userId = "user_id"
    }
}

public struct HAAttributes: Codable {
    public let friendlyName: String

    private enum CodingKeys: String, CodingKey {
        case friendlyName = "friendly_name"
    }
    // Add any other attributes as needed
}

public struct HAState: Codable {
    public let entityId: String
    public let state: String
    public let attributes: [String: String]
    public let lastChanged: String
    public let context: HAContext

    private enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case context
    }
}


public struct HAEventData: Codable {
    public let eventType: String
    public let data: HAData
    public let origin: String
    public let timeFired: String
    public let context: HAContext

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case data
        case origin
        case timeFired = "time_fired"
        case context
    }
}

public struct HAData: Codable {
    // Fields based on your JSON structure
    public let entityId: String
    public let newState: HAState
    public let oldState: HAState

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case newState = "new_state"
        case oldState = "old_state"
    }
}

public struct HAEventMessage {
    public let eventType: String
    public let entityId: String
    public let newState: String
    // ... any other necessary fields
}
