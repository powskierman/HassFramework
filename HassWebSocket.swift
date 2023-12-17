import Foundation
import Starscream
import Combine
import os

public class HassWebSocket: ObservableObject {
    @Published public var connectionState: HassFramework.ConnectionState = .disconnected
    
    private let logger = Logger(subsystem: "com.example.app", category: "network")

    weak var delegate: HassWebSocketDelegate?
    public static let shared = HassWebSocket()
    

    private var socket: WebSocket!
    private let pingInterval: TimeInterval = 60.0
    public var messageId: Int = 0
    
    private var isAuthenticating = false
    @Published public var isAuthenticated = false
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

    private var completionHandlers = [Int: (String?) -> Void]()

    public init() {
        self.messageId = 0
        print("HassWebSocket initialized")
        
        guard let requestURLString = getServerURLFromSecrets(),
              let requestURL = URL(string: requestURLString) else {
            fatalError("Failed to create a URL from the string provided in Secrets.plist or the URL is malformed.")
        }
        
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 5
        self.socket = WebSocket(request: request)
        self.socket.delegate = self
        print("WebSocket initialized with request: \(request)")
    }
    
    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            print("Error converting incoming text to Data.")
            return
        }

        // Try decoding into HAEventWrapper which includes the type and potentially an event
        guard let eventWrapper = try? JSONDecoder().decode(HAEventWrapper.self, from: data) else {
            print("Error decoding message to HAEventWrapper.")
            return
        }

        // Handle the message based on its type
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
            } else {
                print("Event data is missing for 'event' type message")
            }

        case "result":
            print("Received a result message. Handling logic can be added here.")

        default:
            print("Received unknown message type: \(eventWrapper.type)")
        }
    }

   
//    private func handleEventWrapper(_ eventWrapper: HAEventWrapper) {
//        switch eventWrapper.type {
//        case "auth_required":
//            authenticate()
//        case "auth_ok":
//            isAuthenticated = true
//            isAuthenticating = false
//            subscribeToEvents()
//        case "event":
//            // The event type is 'event', now process the event detail
//            if let event = eventWrapper.event {
//                let eventDetail = HAEventData.EventDetail(from: event)
//                for handler in eventMessageHandlers {
//                    handler.handleEventMessage(eventDetail)
//                }
//            } else {
//                print("Event data is missing for 'event' type message")
//            }
//        case "result":
//            print("Received a result message. Handling logic can be added here.")
//        default:
//            print("Received unknown message type: \(eventWrapper.type)")
//        }
//    }
    
    public func addEventMessageHandler(_ handler: EventMessageHandler) {
        eventMessageHandlers.append(handler)
        print("Event message handler added: \(handler)")
    }

    private func getServerURLFromSecrets() -> String? {
        guard let path = Bundle(for: HassWebSocket.self).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let serverURL = dict["HomeAssistantServerURL"] as? String else {
            print("Failed to retrieve HomeAssistantServerURL from Secrets.plist.")
            return nil
        }
        print("Server URL retrieved from Secrets: \(serverURL)")
        return serverURL
    }
    
    public func connect(completion: @escaping (Bool) -> Void) {
        print("Attempting to connect to WebSocket")
        onConnectionStateChanged = { newState in
            print("Connection state changed: \(newState)")
            switch newState {
            case .connected:
                print("WebSocket connected")
                completion(true)
            case .disconnected:
                print("WebSocket disconnected")
                completion(false)
            default:
                print("WebSocket connection state: \(newState)")
                break
            }
        }
        
        socket.connect()
        print("I'm Connecting...")
    }

    public func disconnect() {
        print("Disconnecting WebSocket")
        isAuthenticating = false
        socket.disconnect()
        isAttemptingReconnect = false
        print("isAttemptingReconnect after disconnect: \(isAttemptingReconnect)")
    }
    
    private func getAccessToken() -> String? {
        guard let path = Bundle(for: type(of: self)).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let token = dict["HomeAssistantAccessToken"] as? String else {
            print("Failed to retrieve access token from Secrets.plist.")
            return nil
        }
        
        print("Access token retrieved: \(token)")
        return token
    }
    
    func authenticate() {
        guard !isAuthenticating else { return }
          isAuthenticating = true
        print("Attempting authentication with WebSocket")
        guard let accessToken = getAccessToken() else {
            print("Access token not found, cannot authenticate")
            return
        }
        
        let authMessage = [
            "type": "auth",
            "access_token": accessToken
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: authMessage, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            print("Sending authentication message: \(jsonString)")
            socket.write(string: jsonString)
        }
    }
    
    var isSubscribedToStateChanges = false
    
    public func subscribeToEvents() {
        print("Attempting to subscribe to WebSocket events.")
//        if isSubscribedToStateChanges {
//            print("Already subscribed to state_changed events.")
//            return
//        }
        print("subscribeToEvents called with messageId: \(messageId)")
        messageId += 1
        let subscribeMessage: [String: Any] = [
            "id": messageId,
            "type": "subscribe_events",
            "event_type": "state_changed"
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: subscribeMessage, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            print("Sending subscribe message: \(jsonString)")
            sendTextMessage(jsonString)
        } else {
            print(HAError.unableToSerializeMessage.localizedDescription)
        }
        isSubscribedToStateChanges = true
    }
    
    public func sendTextMessage(_ message: String) {
        print("Preparing to send text message: \(message)")
        guard isConnected() else {
            print("Not connected. Adding message to queue: \(message)")
            messageQueue.append(message)
            return
        }
        print("Sending message: \(message)")
        socket.write(string: message)
        flushMessageQueue()
    }

    private func flushMessageQueue() {
        print("Flushing message queue")
        while isConnected() && !messageQueue.isEmpty {
            let message = messageQueue.removeFirst()
            print("Sending queued message: \(message)")
            socket.write(string: message)
        }
    }

    func determineWebSocketMessageType(data: Data) throws -> WebSocketMessageType {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let type = json["type"] as? String {
            print("Determining WebSocket message type: \(type)")
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
        print("Delegate set for HassWebSocket")
    }

    public func isConnected() -> Bool {
        print("Checking if WebSocket is connected: \(connectionState)")
        return connectionState == .connected
    }
    
    public func updateConnectionStatus() {
         let currentStatus = self.isConnected()
         connectionStatusPublisher.send(currentStatus)
     }

    public func attemptReconnection() {
        guard !isConnected(), !isAttemptingReconnect else {
            print("Already connected or attempting to reconnect")
            return
        }
        print("Attempting reconnection to WebSocket")
        isAttemptingReconnect = true
        DispatchQueue.global().asyncAfter(deadline: .now() + reconnectionInterval) { [weak self] in
            self?.connect { success in
                print("Reconnection attempt completed with success: \(success)")
                self?.isAttemptingReconnect = false
                if !success {
                    self?.attemptReconnection() // Try reconnecting again
                }
            }
        }
    }

    private func startHeartbeat() {
        print("Starting WebSocket heartbeat")
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            print("Sending ping to WebSocket")
            self?.socket.write(ping: Data())
        }
    }

    private func stopHeartbeat() {
        print("Stopping WebSocket heartbeat")
        pingTimer?.invalidate()
    }
}

// WebSocketDelegate extension with additional print statements
extension HassWebSocket: WebSocketDelegate {
    public func websocketDidConnect(socket: WebSocketClient) {
        logger.info("WebSocket is connected")
        print("WebSocket is connected")
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        logger.error("WebSocket is disconnected.")
        print("WebSocket is disconnected: \(error?.localizedDescription ?? "No error")")
    }
    
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
      //  print("HassWebSocket received event: \(event)")
        switch event {
        case .connected(_):
            logger.debug("WebSocket connected event received")
            print("WebSocket connected event received")
            connectionState = .connected
            //startHeartbeat()
            authenticate()
            shouldReconnect = true
        case .disconnected(_, _):
            logger.error("WebSocket disconnected event received in HassWebSocket at didReceive")
            print("WebSocket disconnected event received in HassWebSocket at didReceive")
            connectionState = .disconnected
            isAuthenticated = false
            isSubscribedToStateChanges = false
            stopHeartbeat()
            if shouldReconnect {
                attemptReconnection()
            }
        case .text(let text):
            //print("Received text from WebSocket: \(text)")
            handleIncomingText(text) // Low-level text handling
            delegate?.didReceive(event: event, client: client) // Delegating to higher level

           default:
               // Delegating unhandled events
               print("Received unhandled event: \(event)")
               delegate?.didReceive(event: event, client: client)
       }
   }

    // Function to handle state response
    private func handleStateResponse(_ response: [String: Any]) {
        if let result = response["result"] as? [String: Any],
           let state = result["state"] as? String {
            // Retrieve and call the completion handler
            if let completion = completionHandlers[messageId] {
                completion(state)
                completionHandlers.removeValue(forKey: messageId)
            }
        } else {
            print("Error or unexpected format in state response: \(response)")
        }
    }

    // Function to fetch state
    public func fetchState(for entityId: String, completion: @escaping (String?) -> Void) {
        messageId += 1
        completionHandlers[messageId] = completion
        
        let stateRequest: [String: Any] = [
            "id": messageId,
            "type": "get_states",
            "entity_id": entityId
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: stateRequest, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                sendTextMessage(jsonString)
            }
        } catch {
            print("Error creating state request message: \(error)")
            completion(nil)
        }
    }
}

