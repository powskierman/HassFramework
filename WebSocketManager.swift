
import Foundation
import Starscream
import Combine

public class WebSocketManager: ObservableObject, HassWebSocketDelegate {
 
    public static let shared = WebSocketManager()
    @Published public var websocket: HassWebSocket
    public var reconnectionAttempts = 0
    public let maxReconnectionAttempts = 5  // Define the maximum number of reconnection attempts
    public let reconnectionDelay: TimeInterval = 5.0  // Define the delay between reconnection attempts in seconds
    public var interactionTimer: Timer?
    public let interactionTimeout: TimeInterval = 30
    public var isDisconnectedDueToInactivity = false
    
    private init() {
        self.websocket = HassWebSocket.shared
        self.websocket.delegate = self
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
    
    public func resetInteractionTimer() {
        interactionTimer?.invalidate()
        interactionTimer = Timer.scheduledTimer(withTimeInterval: interactionTimeout, repeats: false) { [weak self] _ in
            print("Timer expired. Checking for disconnection.")
            self?.disconnectDueToInactivity()
        }
        print("Interaction timer reset.")
    }
    
    public func disconnect(webSocketDisconnectedDueToInactivity: Bool = false) {
        print(webSocketDisconnectedDueToInactivity ? "Disconnecting WebSocket due to inactivity." : "Disconnecting WebSocket.")
        guard websocket.connectionState == .connected else {
            print("WebSocket already disconnected.")
            return
        }
        isDisconnectedDueToInactivity = webSocketDisconnectedDueToInactivity
        websocket.disconnect()  // This calls the disconnect method in HassWebSocket
    }
    
    public func websocketDidDisconnect() {
        if isDisconnectedDueToInactivity {
            print("WebSocket disconnected due to inactivity.")
            isDisconnectedDueToInactivity = false
        } else {
            print("WebSocket disconnected. Attempting to reconnect if necessary.")
            attemptReconnectionIfNeeded()
        }
    }
    
    // Call this method to disconnect the WebSocket due to inactivity
       private func disconnectDueToInactivity() {
           print("Disconnecting WebSocket due to inactivity.")
           websocket.disconnect()
       }

    public func attemptReconnection() {
              // Check if the WebSocket is not already connected
              if websocket.connectionState != .connected {
                  print("Attempting to reconnect WebSocket...")
                  websocket.connect { success in
                      if success {
                          self.reconnectionAttempts = 0
                          print("WebSocket reconnected successfully.")
                      } else {
                          print("WebSocket reconnection failed, will retry...")
                          // Optionally, you can implement a retry mechanism here
                      }
                  }
              } else {
                  print("WebSocket is already connected.")
              }
          }
    
    public func attemptReconnectionIfNeeded() {
        if reconnectionAttempts < maxReconnectionAttempts {
            reconnectionAttempts += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + reconnectionDelay) {
                self.connectIfNeeded { success in
                    if success {
                        self.reconnectionAttempts = 0
                    } else {
                        self.attemptReconnectionIfNeeded()
                    }
                }
            }
        } else {
            print("Max reconnection attempts reached.")
        }
    }
}
