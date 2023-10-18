import Starscream
import Combine

public class WebSocketManager: ObservableObject {
    public static let shared = WebSocketManager()
    public var websocket = HassWebSocket.shared
    
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var eventsReceived: [String] = []

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        websocket.$connectionState
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
    }

    public var onConnected: (() -> Void)? {
        didSet {
            websocket.onConnected = onConnected
        }
    }

    public var onDisconnected: (() -> Void)? {
        didSet {
            websocket.onDisconnected = onDisconnected
        }
    }

    public var onEventReceived: ((String) -> Void)? {
        didSet {
            websocket.onEventReceived = { [weak self] event in
                DispatchQueue.main.async {
                    self?.eventsReceived.append(event)
                }
                self?.onEventReceived?(event)
            }
        }
    }

    public func connect() {
        websocket.connect()
    }
    
    public func disconnect() {
        websocket.disconnect()
    }
    
    public func subscribeToEvents() {
        websocket.subscribeToEvents()
    }
    
    func handleEventMessage(_ message: [String: Any]) {
        guard let eventType = message["event_type"] as? String,
              eventType == "state_changed",
              let data = message["data"] as? [String: Any],
              // If you don't use these variables, either replace them with _ or comment them out
              let _ = data["entity_id"] as? String,
              let _ = (data["new_state"] as? [String: Any])?["state"] as? String
        else {
            return
        }
        // If you plan to use entityId and newState later, you can uncomment the below lines
        // let entityId = data["entity_id"] as! String
        // let newState = (data["new_state"] as! [String: Any])["state"] as! String
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
    }
}
