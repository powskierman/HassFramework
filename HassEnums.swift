//
//  HassEnums.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2025-08-10.
//  Updated for clarity and maintainability.
//

import Foundation

/// Represents the current connection state to Home Assistant.
public enum ConnectionState {
    case connected
    case disconnected
    case connecting
    case error
}

/// Internal errors related to WebSocket or message handling.
enum HAError: Error {
    case unknownMessageType
    case unableToSerializeMessage
    case unableToRetrieveServerURL
    case unableToRetrieveAccessToken
    case dataUnavailable
    case customError(String)

    var localizedDescription: String {
        switch self {
        case .unknownMessageType: return "Unknown message type received."
        case .unableToSerializeMessage: return "Unable to serialize the message."
        case .unableToRetrieveServerURL: return "Unable to retrieve the server URL."
        case .unableToRetrieveAccessToken: return "Unable to retrieve the access token."
        case .dataUnavailable: return "Data is unavailable."
        case .customError(let message): return message
        }
    }

    init(_ message: String) {
        self = .customError(message)
    }
}

/// Public-facing errors for HassFramework REST and service operations.
public enum HassError: Error {
    case invalidURL
    case noData
    case encodingError
    case entityNotFound
    case unexpectedResponseType
    case invalidResponse
    case unexpectedStatusCode(Int)
    case unknownError(String)
    case badRequest
    case notFound

    public var localizedDescription: String {
        switch self {
        case .invalidURL: return "The provided URL is invalid."
        case .noData: return "No data was returned by the server."
        case .encodingError: return "Failed to encode request body."
        case .entityNotFound: return "The requested entity was not found."
        case .unexpectedResponseType: return "The server returned an unexpected response type."
        case .invalidResponse: return "The server returned an invalid response."
        case .unexpectedStatusCode(let code): return "Unexpected status code: \(code)."
        case .unknownError(let message): return message
        case .badRequest: return "Bad request. Please check your parameters."
        case .notFound: return "The requested resource was not found."
        }
    }
}

/// Internal mapping of WebSocket message types.
enum WebSocketMessageType {
    case authRequired
    case authOk
    case event
    case result
    case unknown
}

/// Enumeration for high-level message types from Home Assistant.
public enum MessageType: String, Codable {
    case event
    case result
    case command
}
