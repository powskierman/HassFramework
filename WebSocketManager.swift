
import Foundation
import Starscream
import Combine

public class WebSocketManager: ObservableObject, HassWebSocketDelegate {
    public static let shared = WebSocketManager()

    @Published public var websocket: HassWebSocket

    // Initializer
    private init() {
        self.websocket = HassWebSocket.shared
        self.websocket.delegate = self  // Sets the WebSocketManager as the delegate for HassWebSocket
    }

    public func connectIfNeeded(completion: @escaping (Bool) -> Void) {
        print("Checking if WebSocket needs to connect...")
        if websocket.connectionState == .disconnected {
            websocket.connect { success in
                completion(success) // Call the completion handler with the success status
            }
        } else {
            completion(true) // If already connected, call the completion handler with `true`
        }
    }
    
    public func disconnectIfNeeded() {
        print("Checking if WebSocket needs to disconnect...")
        if websocket.connectionState == .connected {
            websocket.disconnect()
        }
    }

    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        print("WebSocketManager didReceive event: \(event)")
        switch event {
        case .connected(_):
            print("WebSocket connected")
            websocket.connectionState = .connected

        case .disconnected(let reason, let code):
            print("WebSocket disconnected with reason: \(reason), code: \(code)")
            websocket.connectionState = .disconnected
            websocket.isAuthenticated = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.websocket.connect(completion: {_ in}) // Reconnect logic
            }

        case .text(let text):
            print("Received text:", text)
            if let data = text.data(using: .utf8) {
                do {
                    let messageType = try websocket.determineWebSocketMessageType(data: data)
                    switch messageType {
                    case .authRequired:
                        websocket.authenticate()
                    case .authOk:
                        websocket.isAuthenticated = true
                    case .event:
                        // Since the event handling has been moved to GarageSocketManager, you can remove any handling here.
                        break
                    case .result:
                        // Handle result messages if needed
                        break
                    case .unknown:
                        print("Unknown WebSocket message type received.")
                    }
                } catch {
                    print("Error determining WebSocket message type: \(error)")
                }
            }
            
        case .binary(let data):
            print("Received binary data:", data)

        case .ping:
            print("Received ping.")
            
        case .pong:
            print("Received pong.")
            
        case .viabilityChanged(let isViable):
            print("Viability changed to: \(isViable)")
            
        case .reconnectSuggested(let shouldReconnect):
            print("Reconnect suggested: \(shouldReconnect)")
            
        case .cancelled:
            print("WebSocket cancelled")

        case .error(let error):
            print("WebSocket error:", error ?? "Unknown error occurred.")

        case .peerClosed:
            print("Peer closed the WebSocket connection.")
        }
    }
}
