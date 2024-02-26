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

public struct HAAttributes: Codable {
    var friendlyName: String?
    var additionalAttributes: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case friendlyName = "friendly_name"
        // No explicit coding key for additionalAttributes, as it will be handled dynamically.
    }

    public init(friendlyName: String? = nil, additionalAttributes: [String: AnyCodable] = [:]) {
        self.friendlyName = friendlyName
        self.additionalAttributes = additionalAttributes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        friendlyName = try container.decodeIfPresent(String.self, forKey: .friendlyName)
        
        let allKeys = container.allKeys.filter { $0 != CodingKeys.friendlyName }
        var tempAdditionalAttributes = [String: AnyCodable]()

        for key in allKeys {
            if let intValue = try? container.decode(Int.self, forKey: key) {
                tempAdditionalAttributes[key.stringValue] = AnyCodable(intValue)
            } else if let stringValue = try? container.decode(String.self, forKey: key) {
                tempAdditionalAttributes[key.stringValue] = AnyCodable(stringValue)
            } else if let boolValue = try? container.decode(Bool.self, forKey: key) {
                tempAdditionalAttributes[key.stringValue] = AnyCodable(boolValue)
            }
            // Extend with other types as needed, or adjust based on your AnyCodable's capabilities.
        }

        self.additionalAttributes = tempAdditionalAttributes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(friendlyName, forKey: .friendlyName)

        var dynamicContainer = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in additionalAttributes {
            guard let codingKey = DynamicCodingKey(stringValue: key) else {
                continue
            }
            try dynamicContainer.encode(value, forKey: codingKey)
        }
    }
}

// Supporting dynamic keys for encoding/decoding additional attributes
struct DynamicCodingKey: CodingKey {
var stringValue: String
var intValue: Int?

init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
}

init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
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
    public let attributes: HAAttributes
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

public struct AnyCodable: Codable {
    public var value: Codable?

    public init<T: Codable>(_ value: T?) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
        guard let value = value else { return }
        
        // This portion needs to be adjusted based on how you plan to handle encoding
        // of different types. For example, you might switch on the type of `value`
        // and encode it accordingly.
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

public struct ScriptResponse: Decodable {
    let entityId: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
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
