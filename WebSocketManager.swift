import Starscream
import Combine


public class WebSocketManager: ObservableObject {
    public static let shared = WebSocketManager()
    lazy var homeAssistantWebSocket = HassWebSocket.shared

//public class WebSocketManager: ObservableObject {
    // Singleton pattern: This provides a shared instance of WebSocketManager
    public var websocket = HassWebSocket.shared
//    public static let shared = WebSocketManager()

    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var eventsReceived: [String] = []
    @Published public var leftDoorClosed: Bool = true


 //   private var homeAssistantWebSocket = HassWebSocket.shared
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        homeAssistantWebSocket.$connectionState
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
    }
    
    public var onConnected: (() -> Void)? {
        didSet {
            homeAssistantWebSocket.onConnected = onConnected
        }
    }

    public var onDisconnected: (() -> Void)? {
        didSet {
            homeAssistantWebSocket.onDisconnected = onDisconnected
        }
    }

    public var onEventReceived: ((String) -> Void)? {
        didSet {
            homeAssistantWebSocket.onEventReceived = { [weak self] event in
                DispatchQueue.main.async {
                    self?.eventsReceived.append(event)
                }
                self?.onEventReceived?(event)
            }
        }
    }

    public func connect() {
        homeAssistantWebSocket.connect()
    }
    
    public func disconnect() {
        homeAssistantWebSocket.disconnect()
    }
    
    public func subscribeToEvents() {
        homeAssistantWebSocket.subscribeToEvents()
    }
    
    func handleEventMessage(_ message: [String: Any]) {
        guard let eventType = message["event_type"] as? String,
              eventType == "state_changed",
              let data = message["data"] as? [String: Any],
              let entityId = data["entity_id"] as? String,
              let newStateData = data["new_state"] as? [String: Any],
              let newState = newStateData["state"] as? String else {
            return
        }

        if entityId == "switch.left_door" {
            self.leftDoorClosed = (newState == "off")
        }
        // Handle other entities similarly
    }
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        guard let data = text.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let message = jsonObject as? [String: Any] else {
            return
        }

        if let messageType = message["type"] as? String, messageType == "event" {
            handleEventMessage(message)
        }
        // Handle other message types...
    }

}
