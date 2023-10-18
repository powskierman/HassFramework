import Foundation

public enum WebSocketMessageType {
    case authRequired
    case authOk
    case event
    case result
}

public struct HAContext: Decodable {
    let id: String
    let parentId: String?
    let userId: String?
}

public struct HAAttributes: Decodable {
    public let friendlyName: String
    // Add any other attributes as needed
}

public struct HAState: Decodable {
    public let entityId: String
    public let state: String
    public let attributes: HAAttributes
    public let lastChanged: String
    public let context: HAContext
    // If you also need the `last_updated`, you can add it here
}

public struct HAEventData: Decodable {
    public let entityId: String
    public let oldState: HAState
    public let newState: HAState
}

public struct HAEventMessage {
    public let eventType: String
    public let entityId: String
    public let newState: String
    // ... any other necessary fields
}
