import Foundation
import Starscream  // Ensure you've imported the necessary library
import Combine

public class WebSocketManager: ObservableObject, HassWebSocketDelegate {
    
    @Published public var websocket: HassWebSocket
    public static let shared = WebSocketManager(websocket: HassWebSocket.shared)

    // Initializer
    public init(websocket: HassWebSocket) {
        self.websocket = websocket
        self.websocket.delegate = self  // This sets the WebSocketManager as the delegate for HassWebSocket
    }

    public func connectIfNeeded(completion: @escaping (Bool) -> Void) {
         print("Checking if WebSocket needs to connect...")
         if websocket.connectionState == .disconnected {
             websocket.connect { success in
                 // Call the completion handler with the success status
                 completion(success)
             }
         } else {
             // If already connected, call the completion handler with `true`
             completion(true)
         }
     }
    
    public func disconnectIfNeeded() {
        print("Checking if WebSocket needs to disconnect...")
        if websocket.connectionState == .connected {
            websocket.disconnect()
        }
    }

    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        print("I'm at didReceive! ")
        switch event {
        case .connected(let headers):
            print("WebSocket connected with headers:", headers)
            websocket.connectionState = .connected

        case .disconnected(let reason, let code):
            print("WebSocket disconnected with reason: \(reason) and code: \(code)")
            websocket.connectionState = .disconnected
            websocket.isAuthenticated = false
            
            // Optionally, consider reconnect logic here if desired.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.websocket.connect(completion: {_ in})
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
                        if let haEventData = try?
                            JSONDecoder().decode(HAEventData.self, from: data) {
                            websocket.handleEventMessage(haEventData)
                        }
                        print("At: case .event!")
                    case .result:
                        // Handle if needed
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
   //         websocket.onPongReceived()
            
        case .viabilityChanged(let isViable):
            print("Viability changed to: \(isViable)")
            
        case .reconnectSuggested(let shouldReconnect):
            print("Reconnect suggested: \(shouldReconnect)")
            
        case .cancelled:
            print("WebSocket cancelled")
            
        case .error(let error):
            print("Error:", error ?? "Unknown error occurred.")
            
        case .peerClosed:
            print("Peer closed the WebSocket connection.")
        }
    }
}
