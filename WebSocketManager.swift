import Foundation
import Starscream

public class WebSocketManager: WebSocketDelegate {
    private let websocket: HassWebSocket

    init(websocket: HassWebSocket) {
        self.websocket = websocket
    }

    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("WebSocket connected with headers:", headers)
            websocket.connectionState = .connected
            websocket.onConnected?()

        case .disconnected(let reason, let code):
            print("WebSocket disconnected with reason: \(reason) and code: \(code)")
            websocket.connectionState = .disconnected
            websocket.isAuthenticated = false
            websocket.onDisconnected?()
            
            // Optionally, consider reconnect logic here as previously outlined.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.websocket.connect()
            }

        case .text(let text):
            print("Received text:", text)
            
            if let data = text.data(using: .utf8) {
                let messageType = websocket.determineWebSocketMessageType(data: data)
                switch messageType {
                case .authRequired:
                    websocket.authenticate()
                case .authOk:
                    websocket.isAuthenticated = true
                case .event:
                    if let haEventData = try? JSONDecoder().decode(HAEventData.self, from: data) {
                        websocket.handleEventMessage(haEventData)
                    }
                case .result: break
                    // Handle if needed
                case .unknown:
                    print("Unknown WebSocket message type received.")
                }
            }

        case .binary(let data):
            print("Received binary data:", data)

        case .ping:
            print("Received ping.")
            
        case .pong:
            print("Received pong.")
            websocket.onPongReceived()

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

    // ... (Any additional methods or properties of WebSocketManager class)


    func stopPingTimer() {
        websocket.pingTimer?.invalidate()
        websocket.pingTimer = nil
    }

}
