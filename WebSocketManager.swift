//
//  WebSocketManager.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//  Corrected and refactored on 2025-08-12.
//

import Foundation
import Starscream
import Combine
import os.log

@MainActor
public final class WebSocketManager: ObservableObject, HassWebSocketDelegate {
    
    // MARK: - Public Properties
    public static let shared = WebSocketManager()
    @Published public var websocket: HassWebSocket
    
    // MARK: - Private Properties
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 10
    private let logger = Logger(subsystem: "com.powskierman.HassFramework", category: "websocket.manager")
    
    // MARK: - Initialization
    private init() {
        self.websocket = HassWebSocket.shared
        self.websocket.setDelegate(self)
        logger.info("WebSocketManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Connect to WebSocket if needed
    public func connectIfNeeded() async -> Bool {
        guard websocket.connectionState == .disconnected else {
            logger.debug("WebSocket already connected or connecting")
            return websocket.connectionState == .connected
        }
        
        logger.info("Attempting WebSocket connection...")
        return await websocket.connect()
    }
    
    /// Connect with completion handler (for backward compatibility)
    public func connectIfNeeded(completion: @escaping (Bool) -> Void) {
        Task {
            let success = await connectIfNeeded()
            completion(success)
        }
    }
    
    /// Force disconnect
    public func disconnect() {
        logger.info("Disconnecting WebSocket...")
        websocket.disconnect()
        reconnectionAttempts = 0
    }
    
    /// Check if WebSocket is connected and authenticated
    public var isConnected: Bool {
        return websocket.isConnected()
    }
    
    /// Get current connection state
    public var connectionState: ConnectionState {
        return websocket.connectionState
    }
    
    // MARK: - HassWebSocketDelegate Implementation
    
    public func websocketDidDisconnect() {
        logger.warning("WebSocket disconnected - delegate notification")
        
        // Handle reconnection logic
        if websocket.shouldReconnect && reconnectionAttempts < maxReconnectionAttempts {
            scheduleReconnection()
        } else if reconnectionAttempts >= maxReconnectionAttempts {
            logger.error("Maximum reconnection attempts reached")
            reconnectionAttempts = 0
        }
    }
    
    #if os(iOS)
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        handleWebSocketEvent(event)
    }
    #endif
    
    // MARK: - Private Methods
    
    private func scheduleReconnection() {
        self.reconnectionAttempts += 1
        
        // Calculate exponential backoff delay (1s, 2s, 4s, 8s, ..., max 60s)
        let baseDelay = min(pow(2.0, Double(self.reconnectionAttempts - 1)), 60.0)
        let jitter = Double.random(in: 0...1.0) // Add jitter to prevent thundering herd
        let delay = baseDelay + jitter
        
        logger.info("Scheduling reconnection attempt #\(self.reconnectionAttempts) in \(delay)s")
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            let success = await self.connectIfNeeded()
            if success {
                self.reconnectionAttempts = 0
                self.logger.info("Reconnection successful")
            }
        }
    }
    
    #if os(iOS)
    private func handleWebSocketEvent(_ event: Starscream.WebSocketEvent) {
        switch event {
        case .connected(let headers):
            logger.info("WebSocket connected with headers: \(headers)")
            reconnectionAttempts = 0
            
        case .disconnected(let reason, let code):
            logger.warning("WebSocket disconnected - reason: \(reason), code: \(code)")
            
        case .text(let text):
            logger.debug("Received WebSocket text message")
            handleTextMessage(text)
            
        case .binary(let data):
            logger.debug("Received WebSocket binary data: \(data.count) bytes")
            
        case .ping(_):
            logger.debug("Received WebSocket ping")
            
        case .pong(_):
            logger.debug("Received WebSocket pong")
            
        case .viabilityChanged(let isViable):
            logger.info("WebSocket viability changed: \(isViable)")
            
        case .reconnectSuggested(let shouldReconnect):
            logger.info("WebSocket reconnect suggested: \(shouldReconnect)")
            if shouldReconnect {
                Task {
                    _ = await connectIfNeeded()
                }
            }
            
        case .cancelled:
            logger.info("WebSocket connection cancelled")
            
        case .error(let error):
            if let error = error {
                logger.error("WebSocket error: \(error.localizedDescription)")
            } else {
                logger.error("WebSocket error: unknown error")
            }
            
        case .peerClosed:
            logger.info("WebSocket peer closed connection")
        }
    }
    #endif
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            logger.error("Failed to convert received text to data")
            return
        }
        
        do {
            let messageType = try websocket.determineWebSocketMessageType(data: data)
            
            switch messageType {
            case .authRequired:
                logger.info("Authentication required")
                // Authentication is now handled internally by HassWebSocket
                
            case .authOk:
                logger.info("Authentication successful")
                
            case .event:
                logger.debug("Received event message")
                // Event handling is now managed by HassWebSocket internally
                
            case .result:
                logger.debug("Received result message")
                // Result handling is now managed by HassWebSocket internally
                
            case .unknown:
                logger.warning("Received unknown WebSocket message type")
            }
        } catch {
            logger.error("Error determining WebSocket message type: \(error.localizedDescription)")
        }
    }
}

// MARK: - Convenience Extensions
extension WebSocketManager {
    /// Subscribe to state changes if connected
    public func subscribeToStateChanges() {
        guard isConnected else {
            logger.warning("Cannot subscribe to state changes - not connected")
            return
        }
        
        websocket.subscribeToEvents()
    }
    
    /// Add an event message handler
    public func addEventHandler(_ handler: EventMessageHandler) {
        websocket.addEventMessageHandler(handler)
        logger.debug("Added event handler to WebSocket")
    }
    
    /// Remove an event message handler
    public func removeEventHandler(_ handler: EventMessageHandler) {
        websocket.removeEventMessageHandler(handler)
        logger.debug("Removed event handler from WebSocket")
    }
    
    /// Get current WebSocket statistics
    public var statistics: [String: Any] {
        return [
            "connectionState": String(describing: connectionState),
            "isConnected": isConnected,
            "reconnectionAttempts": reconnectionAttempts,
            "shouldReconnect": websocket.shouldReconnect
        ]
    }
}

// MARK: - Publisher Extensions
extension WebSocketManager {
    /// Publisher that emits connection state changes
    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        return websocket.$connectionState.eraseToAnyPublisher()
    }
    
    /// Publisher that emits authentication state changes
    public var authenticationStatePublisher: AnyPublisher<Bool, Never> {
        return websocket.$isAuthenticated.eraseToAnyPublisher()
    }
    
    /// Publisher that emits subscription state changes
    public var subscriptionStatePublisher: AnyPublisher<Bool, Never> {
        return websocket.$isSubscribedToStateChanges.eraseToAnyPublisher()
    }
}

// MARK: - Debug Extensions
#if DEBUG
extension WebSocketManager {
    /// Debug method to force reconnection
    public func debugForceReconnect() {
        logger.debug("Debug: Forcing reconnection")
        disconnect()
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            _ = await connectIfNeeded()
        }
    }
    
    /// Debug method to simulate connection failure
    public func debugSimulateFailure() {
        logger.debug("Debug: Simulating connection failure")
        websocket.disconnect()
    }
    
    /// Get detailed debug information
    public var debugInfo: [String: Any] {
        var info = statistics
        info["websocketStats"] = websocket.debugStats()
        return info
    }
}
#endif
