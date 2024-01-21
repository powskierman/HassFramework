import Foundation

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

struct HAAttributes: Codable { // Changed from Decodable to Codable
    let friendlyName: String?

    enum CodingKeys: String, CodingKey {
        case friendlyName = "friendly_name"
    }
}

public struct HAEventData: Codable {
    public let type: String
    public let id: Int?
    public let event: EventDetail

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case event
    }

    public struct EventDetail: Codable {
        public let eventType: String
        public let data: HAData
        public let origin: String?
        public let timeFired: String?
        public let context: HAContext?

        enum CodingKeys: String, CodingKey {
            case eventType = "event_type"
            case data
            case origin
            case timeFired = "time_fired"
            case context
        }
    }
}

public struct HAResultData: Codable {
    public let type: String
    public let id: Int?
    public let success: Bool
    public let result: [HAState] // Assuming HAState struct can represent each state in the array

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case success
        case result
    }
}

public struct HAData: Codable {
    public let entityId: String
    public let oldState: HAState?
    public let newState: HAState?

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case oldState = "old_state"
        case newState = "new_state"
    }
}

public struct HAState: Codable {
    public let entityId: String
    public let state: String
    let attributes: [String: AnyCodable]
    public let lastChanged: String?
    public let lastUpdated: String?
    public let context: HAContext?

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
        case context
    }
}

struct AnyCodable: Codable {
    var value: Codable?

    init<T: Codable>(_ value: T?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        guard let value = value else { return }
        try value.encode(to: encoder)
    }
}
public struct HAEventWrapper: Codable {
    public let type: String
    public let id: Int?
    public let event: HAEventDetail?
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case event
    }
    
    public struct HAEventDetail: Codable {
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
}

public struct HAEntity: Codable {
    public let entityId: String
    public let state: String
    let attributes: HAAttributes
    public let lastChanged: String?
    public let lastUpdated: String?
    public let context: HAContext?

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
        case context
    }
}

extension HAEventData.EventDetail {
    init(from wrapperDetail: HAEventWrapper.HAEventDetail) {
        self.eventType = wrapperDetail.eventType
        self.data = wrapperDetail.data
        self.origin = wrapperDetail.origin
        self.timeFired = wrapperDetail.timeFired
        self.context = wrapperDetail.context
    }
}
