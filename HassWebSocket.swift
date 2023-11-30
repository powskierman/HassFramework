import Foundation
import Starscream
import Combine

public class HassWebSocket: EventMessageHandler {
    public static let shared = HassWebSocket()
    
    @Published public var connectionState: ConnectionState = .disconnected
    private var socket: WebSocket!
    private let pingInterval: TimeInterval = 60.0
    public var messageId: Int = 0
    var isAuthenticated = false
    public var onConnectionStateChanged: ((ConnectionState) -> Void)?
    public var onEventReceived: ((String) -> Void)?
    var pingTimer: Timer?
    private var eventMessageHandlers: [EventMessageHandler] = []
    weak var delegate: HassWebSocketDelegate?

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
    }

    public func disconnect() {
        print("Disconnecting WebSocket")
        socket.disconnect()
        isAttemptingReconnect = false
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
        if isSubscribedToStateChanges {
            print("Already subscribed to state_changed events.")
            return
        }
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

    public func handleEventMessage(_ message: HAEventData) {
        for handler in eventMessageHandlers {
            print("Handling event message with handler: \(handler)")
            handler.handleEventMessage(message)
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
    
    public func setDelegate(_ delegate: HassWebSocketDelegate) {
        self.delegate = delegate
        print("Delegate set for HassWebSocket")
    }

    public func isConnected() -> Bool {
        let connected = connectionState == .connected
        print("Checking if WebSocket is connected: \(connected)")
        return connected
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
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        print("HassWebSocket received event: \(event)")
        switch event {
        case .connected(_):
            print("WebSocket connected event received")
            connectionState = .connected
            startHeartbeat()
            authenticate()
        case .disconnected(_, _):
            print("WebSocket disconnected event received")
            connectionState = .disconnected
            isAuthenticated = false
            isSubscribedToStateChanges = false
            stopHeartbeat()
            attemptReconnection()
        case .text(let text):
            print("Received text from WebSocket: \(text)")
            handleIncomingText(text)
        default:
            print("Received unhandled event: \(event)")
            delegate?.didReceive(event: event, client: client)
        }
    }

    func handleIncomingText(_ text: String) {
        print("Handling incoming text: \(text)")
        // Parse the incoming text to a JSON object
        guard let data = text.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = jsonObject["type"] as? String else {
            print("Error parsing incoming text to JSON.")
            return
        }

        switch type {
        case "auth_ok":
            print("Received authentication OK from WebSocket")
            isAuthenticated = true
            subscribeToEvents()
        case "auth_required":
            print("Authentication required by WebSocket")
            authenticate()
        case "result":
            print("Received result from WebSocket: \(jsonObject)")
            if jsonObject["success"] as? Bool == false {
                print("Received error from WebSocket: \(jsonObject["error"] ?? "Unknown error")")
            } else {
                if let id = jsonObject["id"] as? Int, id == messageId {
                    handleStateResponse(jsonObject) // Handle the state response
                } else {
                    print("Received successful result: \(jsonObject)")
                }
            }
        case "event":
                print("Received event from WebSocket: \(jsonObject)")
                if let event = jsonObject["event"] as? [String: Any], let eventType = event["event_type"] as? String {
                    print("Event type: \(eventType)")
                    if eventType == "state_changed" {
                        print("State changed event received: \(event)")
                        if let eventData = try? JSONSerialization.data(withJSONObject: event, options: []) {
                            do {
                                let haEventData = try JSONDecoder().decode(HAEventData.self, from: eventData)
                                handleEventMessage(haEventData)
                            } catch {
                                print("Error decoding HAEventData: \(error)")
                            }
                        }
                    }
                }
        default:
            print("Received unknown message type: \(type)")
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

