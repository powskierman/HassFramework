import Starscream

public class WebSocketManager: ObservableObject {
    
    // Shared instance
    public static let shared = WebSocketManager()
    
    private var homeAssistantWebSocket = HomeAssistantWebSocket.shared
    private var leftDoorClosed = true
    private var rightDoorClosed = true
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
            print("DEBUG: WebSocket connected.")
            DispatchQueue.main.async {
                self?.connectionState = .connected
            }
            self?.homeAssistantWebSocket.subscribeToEvents()
        }

        homeAssistantWebSocket.onDisconnected = { [weak self] in
            print("DEBUG: WebSocket disconnected.")
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
            }
        }

        homeAssistantWebSocket.onEventReceived = { [weak self] event in
            print("DEBUG: Event received: \(event)")
            
            DispatchQueue.main.async {
                self?.eventsReceived.append(event)
            }
            
            if let data = event.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let entity_id = json["entity_id"] as? String,
               let state = json["state"] as? String {
                   
               DispatchQueue.main.async {
                   switch entity_id {
                       case "binary_sensor.left_door_sensor":
                           self?.leftDoorClosed = (state == "off")
                       case "binary_sensor.right_door_sensor":
                           self?.rightDoorClosed = (state == "off")
                       default:
                           break
                   }
               }
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
    public func setEntityState(entityId: String, newState: String) {
        homeAssistantWebSocket.setEntityState(entityId: entityId, newState: newState)
    }
    public func testFunction() {
        print("Test function called!")
    }

}
