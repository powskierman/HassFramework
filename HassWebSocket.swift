import Foundation
import Starscream

public protocol HassWebSocketDelegate: AnyObject {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient)
}

public class HassWebSocket: EventMessageHandler {
    public static let shared = HassWebSocket()
    
    @Published public var connectionState: ConnectionState = .disconnected
    private var socket: WebSocket!
    private let pingInterval: TimeInterval = 60.0
    public var messageId: Int = 0
    var isAuthenticated = false
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
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
        socket.connect()
        startPingTimer()
        onConnected = {
            completion(true)
        }
        onDisconnected = {
            completion(false)
        }
    }
    
    func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.socket.write(ping: Data())
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if strongSelf.connectionState == .connected {
                    print("No pong received in time, reconnecting...")
                    strongSelf.disconnect()
                    strongSelf.connect(completion: { _ in
                        // You can add any functionality you want to be executed
                        // after the connection attempt here or leave it empty.
                    })
                }
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    public func disconnect() {
        stopPingTimer()
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
    
    public func subscribeToEvents() {
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
    }
    
    public func sendTextMessage(_ message: String) {
        // Print the sent message
        print("Sending text:", message)

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
        // Only deal with the raw events here and update the state
        switch event {
        case .connected(_):
            connectionState = .connected
            onConnected?()
            delegate?.didReceive(event: event, client: client) // Forward the event to the manager
        case .disconnected(_, _):
            connectionState = .disconnected
            isAuthenticated = false
            onDisconnected?()
            delegate?.didReceive(event: event, client: client) // Forward the event to the manager
        default:
            // For other events, just forward them directly
            delegate?.didReceive(event: event, client: client)
        }
    }
    
    func onPongReceived() {
        connectionState = .connected
    }
}
