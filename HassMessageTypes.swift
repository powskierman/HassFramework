//
//  HassMessageTypes.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation

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
