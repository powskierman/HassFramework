//
//  HassProtocols.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation

public protocol EventMessageHandler {
    func handleEventMessage(_ message: HAEventData)
}
protocol WebSocketManagerDelegate: AnyObject {
    func didReceiveWebSocketMessage(_ message: HAEventMessage)
    // ... other methods as necessary
}
