//
//  HassMessageTypes.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//  Refactored on 2025-08-10: public properties, solid Codable support.
//

import Foundation

/// General structure of incoming WebSocket/API messages from Home Assistant.
public struct HAMessage: Codable {
    public let id: Int?
    public let type: MessageType
    public let success: Bool?
    public let event: HAEventData?
    public let result: AnyCodable?

    public init(id: Int? = nil,
                type: MessageType,
                success: Bool? = nil,
                event: HAEventData? = nil,
                result: AnyCodable? = nil) {
        self.id = id
        self.type = type
        self.success = success
        self.event = event
        self.result = result
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case success
        case event
        case result
    }
}
