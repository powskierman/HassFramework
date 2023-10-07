import Starscream

public class WebSocketManager: ObservableObject {
    
    // Shared instance
    public static let shared = WebSocketManager()
    
    private var homeAssistantWebSocket = HomeAssistantWebSocket.shared
    
    @Published public var isConnected: Bool = false
    @Published public var eventsReceived: [String] = []
    
    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    @Published public var connectionState: ConnectionState = .disconnected

    // Make the initializer private
    private init() {
        homeAssistantWebSocket.onConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.connectionState = .connected
            }
        }

        homeAssistantWebSocket.onDisconnected = { [weak self] in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
            }
        }

        homeAssistantWebSocket.onEventReceived = { [weak self] event in
            DispatchQueue.main.async {
                self?.eventsReceived.append(event)
            }
        }
    }
    
    public func connect() {
        connectionState = .connecting
        homeAssistantWebSocket.connect()
    }
        
    public func disconnect() {
        homeAssistantWebSocket.disconnect()
    }
        
    public func subscribeToEvents() {
        homeAssistantWebSocket.subscribeToEvents()
    }
}
