//
//  HassModels.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//  Corrected and refactored on 2025-08-12.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.powskierman.HassFramework", category: "models")

// MARK: - HAContext
public struct HAContext: Codable {
    public let id: String
    public let parentId: String?
    public let userId: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case userId = "user_id"
    }
    
    public init(id: String, parentId: String? = nil, userId: String? = nil) {
        self.id = id
        self.parentId = parentId
        self.userId = userId
    }
}

// MARK: - HAAttributes
public struct HAAttributes: Codable {
    public var friendlyName: String?
    public var additionalAttributes: [String: AnyCodable] = [:]
    
    public init(friendlyName: String? = nil, additionalAttributes: [String: AnyCodable] = [:]) {
        self.friendlyName = friendlyName
        self.additionalAttributes = additionalAttributes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        
        // Handle known keys first
        if let friendlyKey = DynamicCodingKey(stringValue: "friendly_name") {
            friendlyName = try container.decodeIfPresent(String.self, forKey: friendlyKey)
        }
        
        // Decode all remaining keys dynamically
        for key in container.allKeys where key.stringValue != "friendly_name" {
            if let value = try? container.decode(AnyCodable.self, forKey: key) {
                additionalAttributes[key.stringValue] = value
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        
        // Encode friendly_name if present
        if let friendlyName = friendlyName,
           let friendlyKey = DynamicCodingKey(stringValue: "friendly_name") {
            try container.encode(friendlyName, forKey: friendlyKey)
        }
        
        // Encode all additional attributes
        for (key, value) in additionalAttributes {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            try container.encode(value, forKey: codingKey)
        }
    }
}

// MARK: - HAAttributes Convenience Extensions
extension HAAttributes {
    /// Get an attribute value with type safety
    public func getValue<T>(for key: String, as type: T.Type) -> T? {
        return additionalAttributes[key]?.value as? T
    }
    
    /// Common Home Assistant attributes with type safety
    public var temperature: Double? {
        return getValue(for: "temperature", as: Double.self)
    }
    
    public var unitOfMeasurement: String? {
        return getValue(for: "unit_of_measurement", as: String.self)
    }
    
    public var deviceClass: String? {
        return getValue(for: "device_class", as: String.self)
    }
    
    public var icon: String? {
        return getValue(for: "icon", as: String.self)
    }
    
    public var stateClass: String? {
        return getValue(for: "state_class", as: String.self)
    }
    
    public var brightness: Int? {
        return getValue(for: "brightness", as: Int.self)
    }
    
    public var colorMode: String? {
        return getValue(for: "color_mode", as: String.self)
    }
    
    public var supportedFeatures: Int? {
        return getValue(for: "supported_features", as: Int.self)
    }
}

// MARK: - HAEventData
public struct HAEventData: Codable {
    public let type: String
    public let id: Int?
    public let event: EventDetail

    public struct EventDetail: Codable {
        public let eventType: String
        public let data: HAData
        public let origin: String?
        public let timeFired: String?
        public let context: HAContext?

        private enum CodingKeys: String, CodingKey {
            case eventType = "event_type"
            case data
            case origin
            case timeFired = "time_fired"
            case context
        }
        
        public init(eventType: String, data: HAData, origin: String? = nil, timeFired: String? = nil, context: HAContext? = nil) {
            self.eventType = eventType
            self.data = data
            self.origin = origin
            self.timeFired = timeFired
            self.context = context
        }
    }
    
    public init(type: String, id: Int? = nil, event: EventDetail) {
        self.type = type
        self.id = id
        self.event = event
    }
}

// MARK: - HAResultData
public struct HAResultData: Codable {
    public let type: String
    public let id: Int?
    public let success: Bool
    public let result: [HAState]

    public init(type: String, id: Int? = nil, success: Bool, result: [HAState]) {
        self.type = type
        self.id = id
        self.success = success
        self.result = result
    }
}

// MARK: - HAData
public struct HAData: Codable {
    public let entityId: String
    public let oldState: HAState?
    public let newState: HAState?

    private enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case oldState = "old_state"
        case newState = "new_state"
    }
    
    public init(entityId: String, oldState: HAState? = nil, newState: HAState? = nil) {
        self.entityId = entityId
        self.oldState = oldState
        self.newState = newState
    }
}

// MARK: - HAState
public struct HAState: Codable {
    public let entityId: String
    public let state: String
    public let attributes: HAAttributes
    public let lastChanged: String?
    public let lastUpdated: String?
    public let context: HAContext?

    private enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
        case context
    }
    
    public init(entityId: String, state: String, attributes: HAAttributes, lastChanged: String? = nil, lastUpdated: String? = nil, context: HAContext? = nil) {
        self.entityId = entityId
        self.state = state
        self.attributes = attributes
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
        self.context = context
    }
}

// MARK: - HAEntity (Alias for HAState for backward compatibility)
public typealias HAEntity = HAState

// MARK: - HAEventWrapper
public struct HAEventWrapper: Codable {
    public let type: String
    public let id: Int?
    public let event: HAEventDetail?
    
    public struct HAEventDetail: Codable {
        public let eventType: String
        public let data: HAData
        public let origin: String
        public let timeFired: String
        public let context: HAContext
        
        private enum CodingKeys: String, CodingKey {
            case eventType = "event_type"
            case data
            case origin
            case timeFired = "time_fired"
            case context
        }
        
        public init(eventType: String, data: HAData, origin: String, timeFired: String, context: HAContext) {
            self.eventType = eventType
            self.data = data
            self.origin = origin
            self.timeFired = timeFired
            self.context = context
        }
    }
    
    public init(type: String, id: Int? = nil, event: HAEventDetail? = nil) {
        self.type = type
        self.id = id
        self.event = event
    }
}

// MARK: - Service Request/Response Models
public struct ScriptResponse: Codable {
    public let entityId: String
    public let state: String

    private enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
    }
    
    public init(entityId: String, state: String) {
        self.entityId = entityId
        self.state = state
    }
}

public struct ToggleServiceRequest: Codable {
    public let entityId: String
    
    private enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
    }
    
    public init(entityId: String) {
        self.entityId = entityId
    }
}

public struct EmptyResponse: Codable {
    public init() {}
}

// MARK: - Supporting Types

/// Dynamic coding key for handling arbitrary JSON keys
public struct DynamicCodingKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?
    
    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Type-safe wrapper for any Codable value
public struct AnyCodable: Codable {
    public let value: Any
    
    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode in order of most to least specific
        if container.decodeNil() {
            self.value = ()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "AnyCodable could not decode value"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDictionary)
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable could not encode value of type \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - Conversion Extensions
extension HAEventData.EventDetail {
    /// Initialize from HAEventWrapper.HAEventDetail for compatibility
    public init(from wrapperDetail: HAEventWrapper.HAEventDetail) {
        self.init(
            eventType: wrapperDetail.eventType,
            data: wrapperDetail.data,
            origin: wrapperDetail.origin,
            timeFired: wrapperDetail.timeFired,
            context: wrapperDetail.context
        )
    }
}

// MARK: - Utility Extensions
extension HAState {
    /// Check if the entity is currently "on"
    public var isOn: Bool {
        return state.lowercased() == "on"
    }
    
    /// Check if the entity is currently "off"
    public var isOff: Bool {
        return state.lowercased() == "off"
    }
    
    /// Check if the entity is unavailable
    public var isUnavailable: Bool {
        return state.lowercased() == "unavailable"
    }
    
    /// Get the entity domain (e.g., "light" from "light.living_room")
    public var domain: String {
        return String(entityId.split(separator: ".").first ?? "")
    }
    
    /// Get the entity name without domain (e.g., "living_room" from "light.living_room")
    public var entityName: String {
        let components = entityId.split(separator: ".")
        return components.count > 1 ? String(components[1]) : entityId
    }
    
    /// Get display name (friendly_name or entity name as fallback)
    public var displayName: String {
        return attributes.friendlyName ?? entityName.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

extension HAAttributes {
    /// Set an attribute value with type safety
    public mutating func setValue<T: Codable>(_ value: T?, for key: String) {
        if let value = value {
            additionalAttributes[key] = AnyCodable(value)
        } else {
            additionalAttributes.removeValue(forKey: key)
        }
    }
}

// MARK: - Debug Extensions
#if DEBUG
extension HAState: CustomStringConvertible {
    public var description: String {
        return "HAState(entityId: \(entityId), state: \(state), friendlyName: \(attributes.friendlyName ?? "nil"))"
    }
}

extension HAAttributes: CustomStringConvertible {
    public var description: String {
        let additionalCount = additionalAttributes.count
        return "HAAttributes(friendlyName: \(friendlyName ?? "nil"), additionalAttributes: \(additionalCount) items)"
    }
}
#endif
