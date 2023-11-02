//
//  HassProtocols.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation
import Combine

public protocol EventMessageHandler {
    func handleEventMessage(_ message: HAEventData)
}
protocol WebSocketManagerDelegate: AnyObject {
    func didReceiveWebSocketMessage(_ message: HAEventMessage)
    // ... other methods as necessary
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
protocol HAEventProtocol {
    var type: String { get }
    var event_type: String { get }
    var entity_id: String { get }
    var old_state: HAState? { get }
    var new_state: HAState? { get }
}
