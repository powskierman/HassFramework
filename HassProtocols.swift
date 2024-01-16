//
//  HassProtocols.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation
import Combine
import Starscream

public protocol HassWebSocketDelegate: AnyObject {
    func websocketDidDisconnect()
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient)
    // ... other methods
}

public protocol EventMessageHandler {
    func handleEventMessage(_ eventDetail: HAEventData.EventDetail)
    func handleResultMessage(_ text: String)
    // other methods...
}

public protocol WebSocketProvider {
    var connectionState: Published<ConnectionState>.Publisher { get }
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }
    var onEventReceived: ((String) -> Void)? { get set }
    func connect()
    func disconnect()
    func subscribeToEvents()
}

