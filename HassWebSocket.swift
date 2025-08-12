//
//  HassWebSocket.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-10.
//  Corrected and refactored on 2025-08-12.
//

import Foundation
import Starscream
import Combine
import os.log

@MainActor
public final class HassWebSocket: ObservableObject {
    public static let shared = HassWebSocket()
    
    // MARK: - Published Properties
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var isAuthenticated = false
    @Published public var isSubscribedToStateChanges = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.powskierman.HassFramework", category: "websocket")
    private var socket: WebSocket?
    private let pingInterval: TimeInterval = 60.0
    private var messageId: Int = 0
    private var isAuthenticating = false
    private var pingTimer: Timer?
    private var messageQueue: [String] = []
    private var completionHandlers: [Int: ([HAState]?) -> Void] = [:]
    private var eventMessageHandlers: [EventMessageHandler] = []
    
    // MARK: - Reconnection Properties
    public var shouldReconnect = true
    private var reconnectionInterval: TimeInterval = 5.0
    private var isAttemptingReconnect = false
    private var reconnectionAttempts = 0
    private let maxReconnectionInterval: TimeInterval = 60.0
    
    // MARK: - Delegate and Closures
    public weak var delegate: HassWebSocketDelegate?
    public var onConnectionStateChanged: ((ConnectionState) -> Void)?
    public var onEventReceived: ((String) -> Void)?
    
    // MARK: - Publishers
    public var connectionStatusPublisher = PassthroughSubject<Bool, Never>()
    
    // MARK: - Initialization
    private init() {
        setupWebSocket()
    }
    
    private func setupWebSocket() {
        guard let requestURLString = getServerURLFromSecrets(),
              let requestURL = URL(string: requestURLString) else {
            logger.error("Failed to create WebSocket URL from Secrets.plist")
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 10
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        
        logger.info("WebSocket configured for URL: \(requestURL.absoluteString, privacy: .public)")
    }
    
    // MARK: - Public Methods
    
    /// Connect to Home Assistant WebSocket with completion handler
    public func connect(completion: @escaping (Bool) -> Void) {
        guard let socket = socket else {
            logger.error("WebSocket not configured")
            completion(false)
            return
        }
        
        onConnectionStateChanged = { [weak self] newState in
            switch newState {
            case .connected:
                self?.logger.info("WebSocket connected successfully")
                completion(true)
            case .error:
                self?.logger.error("WebSocket connection failed")
                completion(false)
            default:
                break
            }
        }
        
        connectionState = .connecting
        socket.connect()
    }
    
    /// Connect with async/await pattern
    public func connect() async -> Bool {
        return await withCheckedContinuation { continuation in
            connect { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Disconnect from WebSocket
    public func disconnect() {
        logger.info("Disconnecting WebSocket")
        shouldReconnect = false
        isAuthenticating = false
        isAttemptingReconnect = false
        stopHeartbeat()
        socket?.disconnect()
        connectionState = .disconnected
        isAuthenticated = false
        isSubscribedToStateChanges = false
        clearCompletionHandlers()
    }
    
    /// Check if WebSocket is connected
    public func isConnected() -> Bool {
        return connectionState == .connected && isAuthenticated
    }
    
    /// Add event message handler
    public func addEventMessageHandler(_ handler: EventMessageHandler) {
        eventMessageHandlers.append(handler)
        logger.debug("Added event message handler")
    }
    
    /// Remove event message handler
    public func removeEventMessageHandler(_ handler: EventMessageHandler) {
        eventMessageHandlers.removeAll { handler1 in
            return ObjectIdentifier(handler1 as AnyObject) == ObjectIdentifier(handler as AnyObject)
        }
        logger.debug("Removed event message handler")
    }
    
    /// Set delegate
    public func setDelegate(_ delegate: HassWebSocketDelegate) {
        self.delegate = delegate
    }
    
    /// Get next message ID
    public func getNextMessageId() -> Int {
        messageId += 1
        return messageId
    }
    
    /// Subscribe to Home Assistant events
    public func subscribeToEvents() {
        guard isAuthenticated else {
            logger.warning("Cannot subscribe to events - not authenticated")
            return
        }
        
        let currentMessageId = getNextMessageId()
        let subscribeMessage: [String: Any] = [
            "id": currentMessageId,
            "type": "subscribe_events",
            "event_type": "state_changed"
        ]
        
        sendMessage(subscribeMessage) { [weak self] success in
            if success {
                self?.isSubscribedToStateChanges = true
                self?.logger.info("Successfully subscribed to state change events")
            } else {
                self?.logger.error("Failed to subscribe to state change events")
            }
        }
    }
    
    /// Fetch current state of all entities
    public func fetchState(completion: @escaping ([HAState]?) -> Void) {
        guard isConnected() else {
            logger.warning("Cannot fetch state - not connected")
            completion(nil)
            return
        }
        
        let currentMessageId = getNextMessageId()
        let stateRequest: [String: Any] = [
            "id": currentMessageId,
            "type": "get_states"
        ]
        
        completionHandlers[currentMessageId] = completion
        
        sendMessage(stateRequest) { [weak self] success in
            if !success {
                self?.completionHandlers.removeValue(forKey: currentMessageId)
                completion(nil)
            }
        }
    }
    
    /// Fetch state with async/await
    public func fetchState() async -> [HAState]? {
        return await withCheckedContinuation { continuation in
            fetchState { states in
                continuation.resume(returning: states)
            }
        }
    }
    
    /// Send a service call
    public func callService(domain: String, service: String, serviceData: [String: Any] = [:], completion: @escaping (Bool) -> Void) {
        guard isConnected() else {
            logger.warning("Cannot call service - not connected")
            completion(false)
            return
        }
        
        let currentMessageId = getNextMessageId()
        var serviceCall: [String: Any] = [
            "id": currentMessageId,
            "type": "call_service",
            "domain": domain,
            "service": service
        ]
        
        if !serviceData.isEmpty {
            serviceCall["service_data"] = serviceData
        }
        
        sendMessage(serviceCall) { success in
            completion(success)
        }
    }
    
    /// Send service call with async/await
    public func callService(domain: String, service: String, serviceData: [String: Any] = [:]) async -> Bool {
        return await withCheckedContinuation { continuation in
            callService(domain: domain, service: service, serviceData: serviceData) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func sendMessage(_ message: [String: Any], completion: ((Bool) -> Void)? = nil) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                logger.error("Failed to convert message to JSON string")
                completion?(false)
                return
            }
            
            sendTextMessage(jsonString)
            completion?(true)
        } catch {
            logger.error("Failed to serialize message: \(error.localizedDescription)")
            completion?(false)
        }
    }
    
    private func sendTextMessage(_ message: String) {
        guard let socket = socket else {
            logger.error("Socket not available")
            return
        }
        
        guard isConnected() || connectionState == .connecting else {
            logger.debug("Queueing message - not connected")
            messageQueue.append(message)
            return
        }
        
        socket.write(string: message)
        logger.debug("Sent WebSocket message")
        
        // Process queued messages if any
        flushMessageQueue()
    }
    
    private func flushMessageQueue() {
        guard isConnected() else { return }
        
        while !messageQueue.isEmpty {
            let message = messageQueue.removeFirst()
            socket?.write(string: message)
            logger.debug("Sent queued message")
        }
    }
    
    private func handleIncomingText(_ text: String) {
        logger.debug("Received WebSocket message")
        
        guard let data = text.data(using: .utf8) else {
            logger.error("Failed to convert received text to data")
            return
        }
        
        do {
            let messageType = try determineWebSocketMessageType(data: data)
            
            switch messageType {
            case .authRequired:
                handleAuthRequired()
            case .authOk:
                handleAuthOk()
            case .event:
                handleEventMessage(data: data)
            case .result:
                handleResultMessage(data: data)
            case .unknown:
                logger.warning("Received unknown message type")
            }
        } catch {
            logger.error("Failed to process incoming message: \(error.localizedDescription)")
        }
        
        // Notify delegate and closure
        onEventReceived?(text)
    }
    
    private func handleAuthRequired() {
        logger.info("Authentication required")
        authenticate()
    }
    
    private func handleAuthOk() {
        logger.info("Authentication successful")
        isAuthenticated = true
        isAuthenticating = false
        startHeartbeat()
        subscribeToEvents()
        
        // Update connection state after successful auth
        connectionState = .connected
        onConnectionStateChanged?(.connected)
        updateConnectionStatus()
    }
    
    private func handleEventMessage(data: Data) {
        do {
            let eventWrapper = try JSONDecoder().decode(HAEventWrapper.self, from: data)
            
            if let event = eventWrapper.event {
                let eventDetail = HAEventData.EventDetail(from: event)
                
                // Notify all registered handlers
                for handler in eventMessageHandlers {
                    handler.handleEventMessage(eventDetail)
                }
                
                logger.debug("Processed event message for entity: \(event.data.entityId)")
            }
        } catch {
            logger.error("Failed to decode event message: \(error.localizedDescription)")
        }
    }
    
    private func handleResultMessage(data: Data) {
        do {
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let id = jsonResponse["id"] as? Int else {
                logger.error("Invalid result message format")
                return
            }
            
            if let completion = completionHandlers[id] {
                handleStateResponse(jsonResponse, messageId: id)
            } else {
                logger.debug("Received result for message ID \(id) with no completion handler")
            }
            
            // Notify delegate
            for handler in eventMessageHandlers {
                handler.handleResultMessage(String(data: data, encoding: .utf8) ?? "")
            }
        } catch {
            logger.error("Failed to process result message: \(error.localizedDescription)")
        }
    }
    
    private func handleStateResponse(_ response: [String: Any], messageId: Int) {
        guard let completion = completionHandlers[messageId] else {
            return
        }
        
        defer {
            completionHandlers.removeValue(forKey: messageId)
        }
        
        guard let result = response["result"] as? [[String: Any]] else {
            logger.error("Invalid state response format")
            completion(nil)
            return
        }
        
        let states: [HAState] = result.compactMap { stateDict in
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: stateDict, options: [])
                return try JSONDecoder().decode(HAState.self, from: jsonData)
            } catch {
                logger.error("Failed to decode state: \(error.localizedDescription)")
                return nil
            }
        }
        
        logger.info("Successfully decoded \(states.count) states")
        completion(states)
    }
    
    internal func determineWebSocketMessageType(data: Data) throws -> WebSocketMessageType {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let type = json["type"] as? String else {
            throw HAError.unknownMessageType
        }
        
        switch type {
        case "auth_required":
            return .authRequired
        case "auth_ok":
            return .authOk
        case "event":
            return .event
        case "result":
            return .result
        default:
            return .unknown
        }
    }
    
    private func authenticate() {
        guard !isAuthenticating else {
            logger.debug("Authentication already in progress")
            return
        }
        
        isAuthenticating = true
        
        guard let accessToken = getAccessToken() else {
            logger.error("No access token available")
            connectionState = .error
            onConnectionStateChanged?(.error)
            return
        }
        
        let authMessage: [String: Any] = [
            "type": "auth",
            "access_token": accessToken
        ]
        
        sendMessage(authMessage) { [weak self] success in
            if !success {
                self?.logger.error("Failed to send authentication message")
                self?.connectionState = .error
                self?.onConnectionStateChanged?(.error)
            }
        }
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        pingTimer = Timer.scheduledTimer(withTimeInterval: self.pingInterval, repeats: true) { [weak self] _ in
            self?.socket?.write(ping: Data())
            self?.logger.debug("Sent ping")
        }
        logger.info("Started heartbeat with interval: \(self.pingInterval)s")
    }
    
    private func stopHeartbeat() {
        pingTimer?.invalidate()
        pingTimer = nil
        logger.debug("Stopped heartbeat")
    }
    
    public func updateConnectionStatus() {
        let currentStatus = isConnected()
        connectionStatusPublisher.send(currentStatus)
    }
    
    public func attemptReconnection() {
        guard !isConnected(), !isAttemptingReconnect, shouldReconnect else {
            return
        }
        
        isAttemptingReconnect = true
        self.reconnectionAttempts += 1
        
        // Calculate exponential backoff with jitter
        let baseDelay = min(pow(2.0, Double(self.reconnectionAttempts)), maxReconnectionInterval)
        let jitter = Double.random(in: 0...1.0)
        let delay = baseDelay + jitter
        
        logger.info("Attempting reconnection #\(self.reconnectionAttempts) in \(delay)s")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            self.connect { [weak self] success in
                self?.isAttemptingReconnect = false
                if success {
                    self?.reconnectionAttempts = 0
                    self?.logger.info("Reconnection successful")
                } else if self?.shouldReconnect == true {
                    self?.attemptReconnection()
                }
            }
        }
    }
    
    private func clearCompletionHandlers() {
        for (_, completion) in completionHandlers {
            completion(nil)
        }
        completionHandlers.removeAll()
        logger.debug("Cleared completion handlers")
    }
    
    // MARK: - Configuration Methods
    
    public func getServerURLFromSecrets() -> String? {
        guard let path = Bundle(for: HassWebSocket.self).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let serverURL = dict["HomeAssistantServerURL"] as? String else {
            logger.error("Failed to load server URL from Secrets.plist")
            return nil
        }
        return serverURL
    }
    
    public func getAccessToken() -> String? {
        guard let path = Bundle(for: type(of: self)).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let token = dict["HomeAssistantAccessToken"] as? String else {
            logger.error("Failed to load access token from Secrets.plist")
            return nil
        }
        return token
    }
}

// MARK: - WebSocketDelegate
extension HassWebSocket: WebSocketDelegate {
    public func websocketDidConnect(socket: WebSocketClient) {
        logger.info("WebSocket physical connection established")
        // Don't set connectionState to .connected yet - wait for auth
    }
    
    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        if let error = error {
            logger.error("WebSocket disconnected with error: \(error.localizedDescription)")
        } else {
            logger.info("WebSocket disconnected")
        }
        
        connectionState = .disconnected
        isAuthenticated = false
        isSubscribedToStateChanges = false
        isAuthenticating = false
        stopHeartbeat()
        clearCompletionHandlers()
        
        onConnectionStateChanged?(.disconnected)
        updateConnectionStatus()
        delegate?.websocketDidDisconnect()
        
        if shouldReconnect {
            attemptReconnection()
        }
    }
    
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(_):
            logger.debug("WebSocket event: connected")
            // Authentication will be triggered by auth_required message
            
        case .disconnected(let reason, let code):
            logger.info("WebSocket event: disconnected (reason: \(reason), code: \(code))")
            
        case .text(let text):
            handleIncomingText(text)
            
        case .binary(let data):
            logger.debug("Received binary data: \(data.count) bytes")
            
        case .ping(_):
            logger.debug("Received ping")
            
        case .pong(_):
            logger.debug("Received pong")
            
        case .viabilityChanged(let isViable):
            logger.info("WebSocket viability changed: \(isViable)")
            
        case .reconnectSuggested(let shouldReconnect):
            logger.info("WebSocket reconnect suggested: \(shouldReconnect)")
            if shouldReconnect && self.shouldReconnect {
                attemptReconnection()
            }
            
        case .cancelled:
            logger.info("WebSocket cancelled")
            
        case .error(let error):
            if let error = error {
                logger.error("WebSocket error: \(error.localizedDescription)")
            } else {
                logger.error("WebSocket error: unknown")
            }
            connectionState = .error
            onConnectionStateChanged?(.error)
            
        case .peerClosed:
            logger.info("WebSocket peer closed connection")
        }
        
        // Forward to delegate
        delegate?.didReceive(event: event, client: client)
    }
}

// MARK: - Debug Extensions
#if DEBUG
extension HassWebSocket {
    /// Debug method to manually trigger reconnection
    public func debugReconnect() {
        logger.debug("Debug: Manual reconnection triggered")
        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task {
                _ = await self.connect()
            }
        }
    }
    
    /// Debug method to get current statistics
    public func debugStats() -> [String: Any] {
        return [
            "connectionState": String(describing: connectionState),
            "isAuthenticated": isAuthenticated,
            "isSubscribedToStateChanges": isSubscribedToStateChanges,
            "messageId": messageId,
            "queuedMessages": messageQueue.count,
            "pendingCompletions": completionHandlers.count,
            "reconnectionAttempts": reconnectionAttempts
        ]
    }
}
#endif
