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
}


