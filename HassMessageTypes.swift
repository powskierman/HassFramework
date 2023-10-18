//
//  HassMessageTypes.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation

// Enumeration for type of messages
public enum MessageType: String, Decodable {
    case event
    case result
    case command
    // ... any other relevant message types
}

// Struct to encapsulate the general structure of incoming messages
public struct HAMessage: Decodable {
    let id: Int?
    let type: MessageType
    let success: Bool?
    let event: HAEventData?
    let result: AnyCodable? // You'd use something like `AnyCodable` to handle dynamic result types. This is just an example; actual implementation might differ.
    // ... any other general message attributes
}

// This can be a utility you add if you don't already have it.
// It allows you to handle dynamic JSON structures.
struct AnyCodable: Codable {
    private var _value: Codable!
    
    init<T: Codable>(_ value: T?) {
        self._value = value
    }
    
    func encode(to encoder: Encoder) throws {
        try _value.encode(to: encoder)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try decoding into various types, or expand as needed
        if let intValue = try? container.decode(Int.self) {
            _value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            _value = stringValue
        }
        // ... and so on for other potential types.
    }
}
