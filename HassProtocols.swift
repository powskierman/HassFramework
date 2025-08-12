//
//  HassProtocols.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//  Corrected and refactored on 2025-08-12.
//

import Foundation
import Combine
#if canImport(Starscream) && os(iOS)
import Starscream
#endif

// MARK: - WebSocket Delegate Protocol
public protocol HassWebSocketDelegate: AnyObject {
    func websocketDidDisconnect()
    
    #if os(iOS)
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient)
    #endif
}

// MARK: - Event Message Handler Protocol
public protocol EventMessageHandler: AnyObject {
    func handleEventMessage(_ eventDetail: HAEventData.EventDetail)
    func handleResultMessage(_ text: String)
}

// MARK: - WebSocket Provider Protocol
public protocol WebSocketProvider: AnyObject {
    var connectionState: Published<ConnectionState>.Publisher { get }
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }
    var onEventReceived: ((String) -> Void)? { get set }
    
    func connect()
    func disconnect()
    func subscribeToEvents()
}

// MARK: - Home Assistant Command Protocol
public protocol HassCommand {
    var endpoint: String { get }
    var method: String { get }
    var body: Data? { get }
}

// MARK: - State Change Handler Protocol
public protocol StateChangeHandler: AnyObject {
    func handleStateChange(entityId: String, oldState: HAState?, newState: HAState?)
}

// MARK: - Authentication Provider Protocol
public protocol AuthenticationProvider: AnyObject {
    func getAccessToken() -> String?
    func getServerURL() -> URL?
}

// MARK: - Connection Manager Protocol
public protocol ConnectionManager: AnyObject {
    var isConnected: Bool { get }
    var connectionState: ConnectionState { get }
    
    func connect() async -> Bool
    func disconnect()
    func reconnect() async -> Bool
}

// MARK: - Service Call Protocol
public protocol ServiceCallable: AnyObject {
    func callService(domain: String, service: String, serviceData: [String: Any]) async -> Bool
    func callService(domain: String, service: String, entityId: String) async -> Bool
}

// MARK: - Default Implementations for Optional Protocol Methods
extension HassWebSocketDelegate {
    public func websocketDidDisconnect() {
        // Default empty implementation
    }
    
    #if os(iOS)
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        // Default empty implementation
    }
    #endif
}

extension EventMessageHandler {
    public func handleResultMessage(_ text: String) {
        // Default empty implementation
    }
}
