//
//  ContentView.swift
//  websocket_test2
//
//  Created by Michel Lapointe on 2023-09-27.
//

import Foundation
import Starscream

public class HassWebSocket: EventMessageHandler {
    public static let shared = HassWebSocket()
    
    @Published var connectionState: ConnectionState = .disconnected
    private var socket: WebSocket!
    private let pingInterval: TimeInterval = 60.0 // Ping every 60 seconds
    public var messageId: Int = 0
    var isAuthenticated = false
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onEventReceived: ((String) -> Void)?
    var pingTimer: Timer?
    private var eventMessageHandlers: [EventMessageHandler] = []
    
    public init() {
        self.messageId = 0
        
        if let requestURLString = getServerURLFromSecrets(),
           let requestURL = URL(string: requestURLString) {
            var request = URLRequest(url: requestURL)
            request.timeoutInterval = 5
            self.socket = WebSocket(request: request)
            self.socket.delegate = self
        } else {
            fatalError("Failed to create a URL from the string provided in Secrets.plist or the URL is malformed.")
        }
    }
    
    public func addEventMessageHandler(_ handler: EventMessageHandler) {
        eventMessageHandlers.append(handler)
    }

    private func getServerURLFromSecrets() -> String? {
        // Use the more robust method for fetching resource from bundle
        guard let path = Bundle(for: HassWebSocket.self).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let serverURL = dict["HomeAssistantServerURL"] as? String else {
            print("Failed to retrieve HomeAssistantServerURL from Secrets.plist.")
            return nil
        }
        
        return serverURL
    }
    
    public func connect() {
        print("Attempting to connect to WebSocket...")
        socket.connect()
        startPingTimer()
    }
    
    func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.socket.write(ping: Data())
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if strongSelf.connectionState == .connected {
                    print("No pong received in time, reconnecting...")
                    strongSelf.disconnect()
                    strongSelf.connect()
                }
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    public func disconnect() {
        stopPingTimer()
        socket.disconnect()
    }
    
    private func getAccessToken() -> String? {
        // Use the more robust method for fetching resource from bundle
        guard let path = Bundle(for: type(of: self)).path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let token = dict["HomeAssistantAccessToken"] as? String else {
            print("Failed to retrieve access token from Secrets.plist.")
            return nil
        }
        
        return token
    }
    
    func authenticate() {
        guard let accessToken = getAccessToken() else {
            return
        }
        
        let authMessage = [
            "type": "auth",
            "access_token": accessToken
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: authMessage, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            socket.write(string: jsonString)
        } else {
            print("Failed to serialize authentication message.")
        }
    }
    
    public func subscribeToEvents() {
        messageId += 1
        let subscribeMessage: [String: Any] = [
            "id": messageId,
            "type": "subscribe_events",
            "event_type": "state_changed"
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: subscribeMessage, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            sendTextMessage(jsonString)
        } else {
            print("Failed to encode message.")
        }
    }
    
    public func sendTextMessage(_ message: String) {
        socket.write(string: message)
    }
    
    public func handleEventMessage(_ message: HAEventData) {
        for handler in eventMessageHandlers {
            handler.handleEventMessage(message)
        }
    }
    
    func determineWebSocketMessageType(data: Data) -> WebSocketMessageType {
         if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
             let type = json["type"] as? String {
             switch type {
             case "auth_required":
                 return .authRequired
             case "auth_ok":
                 return .authOk
             case "event":
                 return .event
             case "result":
                 return .result
             default:
                 return .unknown
             }
         }
         return .unknown
     }
}


extension HassWebSocket: WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(_):
            connectionState = .connected
            onConnected?()
            print("WebSocket connected")
            
        case .text(let text):
             print("Received text:", text)

             if let data = text.data(using: .utf8) {
                 // We will utilize a function to determine the message type
                 let messageType = determineWebSocketMessageType(data: data)

                 switch messageType {
                 case .authRequired:
                     // Handle authentication required
                     if !self.isAuthenticated {
                         self.authenticate()
                     }
                 case .authOk:
                     // Handle authentication success
                     self.isAuthenticated = true
                 case .event:
                     // Handle event message
                     if let haEventData = try? JSONDecoder().decode(HAEventData.self, from: data) {
                         self.handleEventMessage(haEventData)
                     }
                 case .result:
                     // Handle results if needed
                     // If it's garage-specific, this could be passed to GarageHass
                     break
                 case .unknown:
                     break
                 }
             }
            
        case .binary(let data):
            print("Received binary data:", data)
        case .ping:
            print("Received ping.")
        case .pong:
            print("Received pong.")
            onPongReceived() // Execute the closure
        case .viabilityChanged(let isViable):
            print("Viability changed to: \(isViable)")
        case .reconnectSuggested(let shouldReconnect):
            print("Reconnect suggested: \(shouldReconnect)")
        case .cancelled:
            print("WebSocket cancelled")
        case .error(let error):
            print("Error:", error ?? "Unknown Error")
        case .peerClosed:
            print("Peer closed the WebSocket")
        case .disconnected(let reason, let code):
            connectionState = .disconnected
            isAuthenticated = false // reset the flag
            onDisconnected?()
            print("WebSocket disconnected with reason: \(reason) and code: \(code)")
            
            // Here, we could check the reason or the code and decide if we want to attempt a reconnection.
            // As a basic example, we'll just attempt to reconnect after 5 seconds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.connect() // Attempt reconnection
            }
          }
    }
        func onPongReceived() {
            connectionState = .connected
        }
    }

