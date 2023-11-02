import Foundation
import Starscream
import Combine

public protocol HassWebSocketDelegate: AnyObject {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient)
}

public class HassWebSocket: EventMessageHandler {
    public static let shared = HassWebSocket()
    
    @Published public var connectionState: ConnectionState = .disconnected {
        didSet {
            print("connectionState changed from \(oldValue) to \(connectionState)")
        }
    }
    private var socket: WebSocket!
    private let pingInterval: TimeInterval = 60.0
    public var messageId: Int = 0
    var isAuthenticated = false
    public var onConnectionStateChanged: ((ConnectionState) -> Void)?
//    var onConnected: (() -> Void)?
//    var onDisconnected: (() -> Void)?
    public var onEventReceived: ((String) -> Void)?
    var pingTimer: Timer?
    private var eventMessageHandlers: [EventMessageHandler] = []

    // Our custom delegate property
    weak var delegate: HassWebSocketDelegate?
    
    public init() {
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
    
    public func addEventMessageHandler(_ handler: EventMessageHandler) {
        eventMessageHandlers.append(handler)
    }

    private func getServerURLFromSecrets() -> String? {
        guard let path = Bundle(for: HassWebSocket.self).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let serverURL = dict["HomeAssistantServerURL"] as? String else {
            print("Failed to retrieve HomeAssistantServerURL from Secrets.plist.")
            return nil
        }
        
        return serverURL
    }
    
    public func connect(completion: @escaping (Bool) -> Void) {
        // Register for connection state changes
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
        
        // Initiate the connection
        socket.connect()
    }

    
    public func disconnect() {

        socket.disconnect()
    }
    
    private func getAccessToken() -> String? {
        guard let path = Bundle(for: type(of: self)).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let token = dict["HomeAssistantAccessToken"] as? String else {
            print("Failed to retrieve access token from Secrets.plist.")
            return nil
        }
        
        return token
    }
    
    func authenticate() {
        print("Attempting to authenticate with WebSocket.")
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
        } else {
            print(HAError.unableToSerializeMessage.localizedDescription)
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
            sendTextMessage(jsonString)
        } else {
            print(HAError.unableToSerializeMessage.localizedDescription)
        }
        isSubscribedToStateChanges = true
    }
    
    public func sendTextMessage(_ message: String) {
        // Print the sent message
        print("Attempting to send WebSocket message: \(message)")

        // If not connected, reconnect
        if !isConnected() {
            connect { (success) in
                if success && self.isAuthenticated {
                    self.socket.write(string: message)
                } else if !self.isAuthenticated {
                    self.authenticate()
                    // Ideally, add a similar callback mechanism for authentication
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.socket.write(string: message)
                    }
                }
            }
        } else if !isAuthenticated {
            self.authenticate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.socket.write(string: message)
            }
        } else {
            socket.write(string: message)
        }
    }

    public func handleEventMessage(_ message: HAEventData) {
        for handler in eventMessageHandlers {
            handler.handleEventMessage(message)
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
    
    public func setDelegate(_ delegate: HassWebSocketDelegate) {
        self.delegate = delegate
    }
    public func isConnected() -> Bool {
        return connectionState == .connected
    }
}


extension HassWebSocket: WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        print("HassWebSocket received event: \(event)")
        switch event {
        case .connected(_):
            DispatchQueue.main.async {
                self.connectionState = .connected
                self.authenticate() // Make sure to authenticate first if needed
            }
        case .text(let text):
             handleIncomingText(text)

        case .disconnected(_, _):
            DispatchQueue.main.async {
                self.connectionState = .disconnected
                self.isAuthenticated = false
                self.isSubscribedToStateChanges = false // Reset the subscription flag
            }
        default:
            // For other events, just forward them directly
            delegate?.didReceive(event: event, client: client)
        }
    }
    
    func handleIncomingText(_ text: String) {
        // Parse the incoming text to a JSON object
        guard let data = text.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = jsonObject["type"] as? String else {
            print("Error parsing incoming text to JSON.")
            return
        }
        
        switch type {
        case "auth_ok":
            isAuthenticated = true
            print("Authenticated successfully with WebSocket.")
            subscribeToEvents()
        case "auth_required":
            authenticate()
        case "result":
            if jsonObject["success"] as? Bool == false {
                // Handle errors.
                print("Received error from WebSocket: \(jsonObject["error"] ?? "Unknown error")")
            } else {
                // Handle success if needed.
                print("Received successful result: \(jsonObject)")
            }
        case "event":
            // Handle the event data.
            if let event = jsonObject["event"] as? [String: Any] {
                handleEvent(event)
            }
        default:
            print("Received unknown message type: \(type)")
        }
    }

    func handleEvent(_ event: [String: Any]) {
        // Here you can handle different types of events
        if let eventType = event["event_type"] as? String {
            if eventType == "state_changed" {
                // Process the state_changed event
                if let eventData = event["data"] as? [String: Any] {
                    // You can further process the data or forward it to a delegate or notification
                    print("State changed event data: \(eventData)")
                    // For example, call a delegate method
                    // self.delegate?.didReceiveStateChangeEvent(eventData)
                }
            } else {
                print("Received an unhandled event type: \(eventType)")
            }
        } else {
            print("Event type not found in the event dictionary")
        }
    }

    
    func onPongReceived() {
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
    }
}
