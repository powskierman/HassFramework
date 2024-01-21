//
//  ConnectionState.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-10.
//

import Foundation
public enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

enum HAError: Error {
    case unknownMessageType
    case unableToSerializeMessage
    case unableToRetrieveServerURL
    case unableToRetrieveAccessToken
    case dataUnavailable
    case customError(String)

    var localizedDescription: String {
        switch self {
        case .unknownMessageType:
            return "Unknown message type received."
        case .unableToSerializeMessage:
            return "Unable to serialize the message."
        case .unableToRetrieveServerURL:
            return "Unable to retrieve the server URL."
        case .unableToRetrieveAccessToken:
            return "Unable to retrieve the access token."
        case .dataUnavailable:
            return "Data is unavailable."
        case .customError(let message):
            return message
        }
    }

    // Initializer for custom error messages
    init(_ message: String) {
        self = .customError(message)
    }
}

enum HassError: Error {
    case invalidURL
    case noData
    case encodingError
    case entityNotFound
}

enum WebSocketMessageType {
    case authRequired
    case authOk
    case event
    case result
    case unknown
}

// Enumeration for type of messages
public enum MessageType: String, Decodable {
    case event
    case result
    case command
    // ... any other relevant message types
}


