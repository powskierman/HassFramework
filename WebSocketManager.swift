import Foundation
import Combine
import Starscream

public class WebSocketManager: ObservableObject, WebSocketDelegate {
    // Singleton pattern to ensure a single instance of WebSocketManager
    public static let shared = WebSocketManager()

    // Properties
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var eventsReceived: [String] = []
    @Published public var leftDoorClosed: Bool = true

    public var websocket: HassWebSocket = HassWebSocket.shared
    private var cancellables: Set<AnyCancellable> = []

    public init() {
        setupBindings()
    }

    private func setupBindings() {
        websocket.$connectionState
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
    }

    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("WebSocket connected with headers:", headers)
            print("Before update: \(websocket.connectionState)")
            websocket.connectionState = .connected
            print("After update: \(websocket.connectionState)")
            websocket.onConnected?()

        case .disconnected(let reason, let code):
            print("WebSocket disconnected with reason: \(reason) and code: \(code)")
            print("Before disconnect update: \(websocket.connectionState)")
            websocket.connectionState = .disconnected
            print("After disconnect update: \(websocket.connectionState)")
            websocket.isAuthenticated = false
            websocket.onDisconnected?()
            
            // Optionally, consider reconnect logic here as previously outlined.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.websocket.connect()
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
                        if let haEventData = try? JSONDecoder().decode(HAEventData.self, from: data) {
                            websocket.handleEventMessage(haEventData)
                        }
                    case .result: break
                        // Handle if needed
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

    public func connect() {
        websocket.connect()
    }

    public func disconnect() {
        websocket.disconnect()
    }

    public func subscribeToEvents() {
        websocket.subscribeToEvents()
    }

    // Additional methods if required ...
}
