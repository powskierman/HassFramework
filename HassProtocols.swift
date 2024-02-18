//
//  HassProtocols.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation
import Combine
#if canImport(Starscream) && os(iOS)
import Starscream
#endif


public protocol HassWebSocketDelegate: AnyObject {
    func websocketDidDisconnect()
#if os(iOS)
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient)
    #endif
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

public protocol HassCommand {
    var endpoint: String { get }
    var method: String { get }
    var body: Data? { get }
}
