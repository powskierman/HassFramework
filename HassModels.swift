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
    public var friendlyName: String?
    public var additionalAttributes: [String: Any] = [:]
    
    enum CodingKeys: String, CodingKey {
        case friendlyName = "friendly_name"
        case attributes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        friendlyName = try container.decodeIfPresent(String.self, forKey: .friendlyName)
        
        if let attributesContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .attributes) {
            for key in attributesContainer.allKeys {
                if key == .friendlyName {
                    continue
                }
                
                if let value = try? attributesContainer.decode(Int.self, forKey: key) {
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode(Double.self, forKey: key) {
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode(String.self, forKey: key) {
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode(Bool.self, forKey: key) {
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode([String].self, forKey: key) {
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode([Int].self, forKey: key) {
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode([Double].self, forKey: key) {
                    additionalAttributes[key.stringValue] = value
                }
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(friendlyName, forKey: .friendlyName)
        
        var attributesContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .attributes)
        for (key, value) in additionalAttributes {
            if let intValue = value as? Int {
                try attributesContainer.encode(intValue, forKey: CodingKeys(stringValue: key)!)
            } else if let doubleValue = value as? Double {
                try attributesContainer.encode(doubleValue, forKey: CodingKeys(stringValue: key)!)
            } else if let stringValue = value as? String {
                try attributesContainer.encode(stringValue, forKey: CodingKeys(stringValue: key)!)
            } else if let boolValue = value as? Bool {
                try attributesContainer.encode(boolValue, forKey: CodingKeys(stringValue: key)!)
            } else if let stringArrayValue = value as? [String] {
                try attributesContainer.encode(stringArrayValue, forKey: CodingKeys(stringValue: key)!)
            } else if let intArrayValue = value as? [Int] {
                try attributesContainer.encode(intArrayValue, forKey: CodingKeys(stringValue: key)!)
            } else if let doubleArrayValue = value as? [Double] {
                try attributesContainer.encode(doubleArrayValue, forKey: CodingKeys(stringValue: key)!)
            }
        }
    }
}



extension HAAttributes {
    mutating func decodeAdditionalAttributes(from decoder: Decoder) throws {
        print("Decoding additional attributes...")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let attributesContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .attributes) {
            for key in attributesContainer.allKeys {
                print("Decoding key: \(key.stringValue)")
                
                if key == .friendlyName {
                    continue
                }
                
                if let value = try? attributesContainer.decode(Int.self, forKey: key) {
                    print("Decoded Int value: \(value)")
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode(Double.self, forKey: key) {
                    print("Decoded Double value: \(value)")
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode(String.self, forKey: key) {
                    print("Decoded String value: \(value)")
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode(Bool.self, forKey: key) {
                    print("Decoded Bool value: \(value)")
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode([String].self, forKey: key) {
                    print("Decoded [String] value: \(value)")
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode([Int].self, forKey: key) {
                    print("Decoded [Int] value: \(value)")
                    additionalAttributes[key.stringValue] = value
                } else if let value = try? attributesContainer.decode([Double].self, forKey: key) {
                    print("Decoded [Double] value: \(value)")
                    additionalAttributes[key.stringValue] = value
                } else {
                    print("Failed to decode value for key: \(key.stringValue)")
                }
            }
        }
        
        print("Decoded additional attributes: \(additionalAttributes)")
    }
}

struct StringKeyedDictionary: Codable {
    let value: [String: AnyCodable]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var dictionary: [String: AnyCodable] = [:]
        for key in container.allKeys {
            if let value = try? container.decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = AnyCodable(value)
            } else if let value = try? container.decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = AnyCodable(value)
            } else if let value = try? container.decode(String.self, forKey: key) {
                dictionary[key.stringValue] = AnyCodable(value)
            } else if let value = try? container.decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = AnyCodable(value)
            }
        }
        
        self.value = dictionary
        
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in value {
                guard let codingKey = DynamicCodingKey(stringValue: key) else {
                    continue
                }
                try value.encode(to: container.superEncoder(forKey: codingKey))
            }
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
    
    public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(entityId, forKey: .entityId)
            try container.encode(state, forKey: .state)
            try container.encode(attributes, forKey: .attributes)
            try container.encodeIfPresent(lastChanged, forKey: .lastChanged)
            try container.encodeIfPresent(lastUpdated, forKey: .lastUpdated)
            try container.encodeIfPresent(context, forKey: .context)
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
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringArray = try? container.decode([String].self) {
            value = stringArray
        } else if let intArray = try? container.decode([Int].self) {
            value = intArray
        } else {
            // Log an error or a warning when encountering an unknown type
            print("Warning: AnyCodable encountered an unknown type that could not be decoded.")
            value = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard let value = value else {
            print("AnyCodable contains a nil value and cannot be encoded.")
            throw EncodingError.invalidValue(value as Any, EncodingError.Context(codingPath: [], debugDescription: "Nil value cannot be encoded."))
        }
        
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringArray = value as? [String] {
            try container.encode(stringArray)
        } else if let intArray = value as? [Int] {
            try container.encode(intArray)
        } else {
            // Log an error for unsupported types
            let debugDescription = "AnyCodable contains an unsupported type (\(type(of: value))) that cannot be encoded."
            print("Error: \(debugDescription)")
            throw EncodingError.invalidValue(value as Any, EncodingError.Context(codingPath: [], debugDescription: debugDescription))
        }
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
    public var entityId: String
    public var state: String
    public var attributes: HAAttributes
    public var lastChanged: String?
    public var lastUpdated: String?
    public var context: HAContext?
    
    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
        case context
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityId = try container.decode(String.self, forKey: .entityId)
        state = try container.decode(String.self, forKey: .state)
        attributes = try container.decode(HAAttributes.self, forKey: .attributes)
        lastChanged = try container.decodeIfPresent(String.self, forKey: .lastChanged)
        lastUpdated = try container.decodeIfPresent(String.self, forKey: .lastUpdated)
        context = try container.decodeIfPresent(HAContext.self, forKey: .context)
        
        // Call decodeAdditionalAttributes after decoding HAAttributes
        try attributes.decodeAdditionalAttributes(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(entityId, forKey: .entityId)
            try container.encode(state, forKey: .state)
            try container.encode(attributes, forKey: .attributes)
            try container.encode(lastChanged, forKey: .lastChanged)
            try container.encode(lastUpdated, forKey: .lastUpdated)
            try container.encode(context, forKey: .context)
        }
    // ... other code ...
}

public struct ScriptResponse: Decodable {
    let entityId: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
    }
}

public struct ToggleServiceRequest: Encodable {
    let entityId: String
    
    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
    }
}

public struct EmptyResponse: Decodable {}

extension HAEventData.EventDetail {
    init(from wrapperDetail: HAEventWrapper.HAEventDetail) {
        self.eventType = wrapperDetail.eventType
        self.data = wrapperDetail.data
        self.origin = wrapperDetail.origin
        self.timeFired = wrapperDetail.timeFired
        self.context = wrapperDetail.context
    }
}

extension HassError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .noData:
            return "No data received."
        case .encodingError:
            return "Failed to encode the request."
        case .entityNotFound:
            return "Entity not found."
        case .unexpectedResponseType:
            return "Unexpected response type."
        case .invalidResponse:
            return "Invalid response from the server."
        case .unexpectedStatusCode(let statusCode):
            return "Unexpected status code: \(statusCode)."
        case .unknownError(let message):
            return "Unknown error: \(message)."
        case .badRequest:
            return "Bad request sent."
        case .notFound:
            return "Requested resource not found."
        }
    }
}
