
import Foundation
import Starscream
import Combine
import os

public class WebSocketManager: ObservableObject, HassWebSocketDelegate {
    public static let shared = WebSocketManager()
    @Published public var websocket: HassWebSocket
    private var reconnectionAttempts = 0
    private let logger = Logger(subsystem: "com.example.app", category: "network.manager")


    // Initializer
    private init() {
        self.websocket = HassWebSocket.shared
        self.websocket.delegate = self  // Sets the WebSocketManager as the delegate for HassWebSocket
    }

    public func connectIfNeeded(completion: @escaping (Bool) -> Void) {
        // print("Checking if WebSocket needs to connect...")
        if websocket.connectionState == .disconnected {
            websocket.connect { success in
                completion(success) // Call the completion handler with the success status
            }
        } else {
            completion(true) // If already connected, call the completion handler with `true`
        }
    }

    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
  //      // print("WebSocketManager didReceive event: \(event)")
        switch event {
        case .connected(_):
            // print("WebSocket connected")
            websocket.connectionState = .connected

        case .disconnected:
            logger.warning("WebSocket disconnected, attempting reconnection")
            reconnectionAttempts += 1
            let delay = min(pow(2.0, Double(reconnectionAttempts)), 60) // Exponential backoff with a max delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.websocket.connect(completion: { success in
                    if success {
                        self.reconnectionAttempts = 0
                    }
                })
            }

        case .text(let text):
        //    // print("Received text:", text)
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
                    // print("Error determining WebSocket message type: \(error)")
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
            
//        default:
//            // Cover all other cases with a default case
//            // This can be left empty if there's no specific handling needed
//            break
        }
    }
}
