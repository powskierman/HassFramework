import Foundation
import Starscream
import Combine
import os

public class HassWebSocket: ObservableObject {
    public static let shared = HassWebSocket()
//    private init() {}

    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var isAuthenticated = false
    @Published public var isSubscribedToStateChanges = false
    
    private let logger = Logger(subsystem: "com.example.app", category: "network")

    weak var delegate: HassWebSocketDelegate?

    private var socket: WebSocket!
    private let pingInterval: TimeInterval = 60.0
    public var messageId: Int = 0
    
    private var isAuthenticating = false
    public var onConnectionStateChanged: ((ConnectionState) -> Void)?
    public var onEventReceived: ((String) -> Void)?
    var pingTimer: Timer?
    private var eventMessageHandlers: [EventMessageHandler] = []
    // Publisher to emit connection status changes
    public var connectionStatusPublisher = PassthroughSubject<Bool, Never>()
 
    public var shouldReconnect = true
    private var reconnectionInterval: TimeInterval = 5.0
    private var isAttemptingReconnect = false
    private var messageQueue: [String] = []

    var completionHandlers: [Int: ([HAState]?) -> Void] = [:]

    init() {
        self.messageId = 0
        
        guard let requestURLString = getServerURLFromSecrets(),
              let requestURL = URL(string: requestURLString) else {
            fatalError("Failed to create a URL from the string provided in Secrets.plist or the URL is malformed.")
        }
        
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 5
        self.socket = WebSocket(request: request)
        self.socket.delegate = self
    }
    
    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            return
        }

        guard let eventWrapper = try? JSONDecoder().decode(HAEventWrapper.self, from: data) else {
            return
        }

        switch eventWrapper.type {
        case "auth_required":
            authenticate()
        case "auth_ok":
            isAuthenticated = true
            isAuthenticating = false
            subscribeToEvents()
        case "event":
            if let event = eventWrapper.event {
                let eventDetail = HAEventData.EventDetail(from: event)
                for handler in eventMessageHandlers {
                    handler.handleEventMessage(eventDetail)
                }
            }
        case "result":
            if let data = text.data(using: .utf8),
               let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []),
               let responseDict = jsonResponse as? [String: Any],
               let id = responseDict["id"] as? Int {
                
                if completionHandlers[id] != nil {
                    handleStateResponse(responseDict, messageId: id)
                }
            }
        default:
            print("Received unknown message type: \(eventWrapper.type)")
        }
    }

    public func addEventMessageHandler(_ handler: EventMessageHandler) {
        eventMessageHandlers.append(handler)
    }

    public func getServerURLFromSecrets() -> String? {
        guard let path = Bundle(for: HassWebSocket.self).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let serverURL = dict["HomeAssistantServerURL"] as? String else {
            return nil
        }
        return serverURL
    }
    
    public func connect(completion: @escaping (Bool) -> Void) {
        onConnectionStateChanged = { newState in
            switch newState {
            case .connected:
                completion(true)
            case .disconnected:
                completion(false)
            default:
                break
            }
        }
        
        socket.connect()
    }

    public func disconnect() {
        isAuthenticating = false
        socket.disconnect()
        isAttemptingReconnect = false
    }
    
    public func getAccessToken() -> String? {
        guard let path = Bundle(for: type(of: self)).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let token = dict["HomeAssistantAccessToken"] as? String else {
            return nil
        }
        return token
    }
    
    func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        guard let accessToken = getAccessToken() else {
            return
        }
        
        let authMessage = [
            "type": "auth",
            "access_token": accessToken
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: authMessage, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            socket.write(string: jsonString)
        }
    }
    
    public func subscribeToEvents() {
        messageId += 1
        let subscribeMessage: [String: Any] = [
            "id": messageId,
            "type": "subscribe_events",
            "event_type": "state_changed"
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: subscribeMessage, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            sendTextMessage(jsonString)
        }
        isSubscribedToStateChanges = true
    }
    
    public func sendTextMessage(_ message: String) {
        guard isConnected() else {
            messageQueue.append(message)
            return
        }
        socket.write(string: message)
        flushMessageQueue()
    }

    private func flushMessageQueue() {
        while isConnected() && !messageQueue.isEmpty {
            let message = messageQueue.removeFirst()
            socket.write(string: message)
        }
    }

    func determineWebSocketMessageType(data: Data) throws -> WebSocketMessageType {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let type = json["type"] as? String {
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
                throw HAError.unknownMessageType
            }
        }
        throw HAError.unknownMessageType
    }
    
    public func getNextMessageId() -> Int {
        messageId += 1
        return messageId
    }
    
    func setDelegate(_ delegate: HassWebSocketDelegate) {
        self.delegate = delegate
    }

    public func isConnected() -> Bool {
        return connectionState == .connected
    }
    
    public func updateConnectionStatus() {
        let currentStatus = self.isConnected()
        connectionStatusPublisher.send(currentStatus)
    }

    public func attemptReconnection() {
        guard !isConnected(), !isAttemptingReconnect else {
            return
        }
        isAttemptingReconnect = true
        DispatchQueue.global().asyncAfter(deadline: .now() + reconnectionInterval) { [weak self] in
            self?.connect { success in
                self?.isAttemptingReconnect = false
                if !success {
                    self?.attemptReconnection()
                }
            }
        }
    }

    private func startHeartbeat() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.socket.write(ping: Data())
        }
    }

    private func stopHeartbeat() {
        pingTimer?.invalidate()
    }
}

// WebSocketDelegate extension
extension HassWebSocket: WebSocketDelegate {
    public func websocketDidConnect(socket: WebSocketClient) {
        logger.info("WebSocket is connected")
        connectionState = .connected
    }
    
    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        logger.error("WebSocket is disconnected.")
        connectionState = .disconnected
    }
    
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(_):
            connectionState = .connected
            authenticate()
            shouldReconnect = true
        case .disconnected(_, _):
            connectionState = .disconnected
            isAuthenticated = false
            isSubscribedToStateChanges = false
            stopHeartbeat()
            if shouldReconnect {
                attemptReconnection()
            }
        case .text(let text):
            handleIncomingText(text)
            delegate?.didReceive(event: event, client: client)
        default:
            delegate?.didReceive(event: event, client: client)
        }
    }
    
    private func handleStateResponse(_ response: [String: Any], messageId: Int) {
        if let result = response["result"] as? [[String: Any]] {
            let states: [HAState] = result.compactMap { stateDict in
                guard let jsonData = try? JSONSerialization.data(withJSONObject: stateDict, options: []),
                      let state = try? JSONDecoder().decode(HAState.self, from: jsonData) else {
                    return nil
                }
                return state
            }
            
            if let completion = completionHandlers[messageId] {
                completion(states)
                completionHandlers.removeValue(forKey: messageId)
            }
        }
    }
    
    public func fetchState(completion: @escaping ([HAState]?) -> Void) {
        messageId += 1
        let currentMessageId = messageId
        
        let stateRequest: [String: Any] = [
            "id": currentMessageId,
            "type": "get_states"
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: stateRequest, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                sendTextMessage(jsonString)
                
                completionHandlers[currentMessageId] = { states in
                    completion(states)
                }
            }
        } catch {
            completion(nil)
        }
    }
}
