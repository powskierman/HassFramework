import Foundation

enum WebSocketMessageType {
    case authRequired
    case authOk
    case event
    case result
    case unknown
}

public struct HAContext: Decodable {
    let id: String
    let parentId: String?
    let userId: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case userId = "user_id"
    }
}

public struct HAAttributes: Decodable {
    public let friendlyName: String

    private enum CodingKeys: String, CodingKey {
        case friendlyName = "friendly_name"
    }
    // Add any other attributes as needed
}

public struct HAState: Decodable {
    public let entityId: String
    public let state: String
    public let attributes: HAAttributes
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


public struct HAEventData: Decodable, HAEventProtocol {
    public let type: String
    public let event_type: String
    public let entity_id: String
    public let old_state: HAState?
    public let new_state: HAState?
}


public struct HAEventMessage {
    public let eventType: String
    public let entityId: String
    public let newState: String
    // ... any other necessary fields
}
