import SwiftUI
import Starscream

class WebSocketManager: ObservableObject {
    private var homeAssistantWebSocket = HomeAssistantWebSocket()

    @Published var isConnected: Bool = false
    @Published var eventsReceived: [String] = []  // Changed from a singular event to an array of events
    
    init() {
        homeAssistantWebSocket.onConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = true
            }
        }

        homeAssistantWebSocket.onDisconnected = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }

        homeAssistantWebSocket.onEventReceived = { [weak self] event in
            DispatchQueue.main.async {
                self?.eventsReceived.append(event)  // Append each event to the eventsReceived array
            }
        }
    }
    
    func connect() {
        homeAssistantWebSocket.connect()
    }
    
    func disconnect() {
        homeAssistantWebSocket.disconnect()
    }
    
    func subscribeToEvents() {
        homeAssistantWebSocket.subscribeToEvents()
    }
}
