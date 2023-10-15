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
    private var isAuthenticated = false
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onEventReceived: ((String) -> Void)?
    private var pingTimer: Timer?
    private var lastSentMessage: String?
    private var onPongReceived: (() -> Void)?
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
    
    public func addEventMessageHandler(_ handler:EventMessageHandler){
        eventMessageHandlers.append(handler)
    }

    
    private func getServerURLFromSecrets() -> String? {
        let frameworkBundle = Bundle(for: HassWebSocket.self)
        
        guard let path = frameworkBundle.path(forResource: "Secrets", ofType: "plist"),
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
    
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            if let _ = self.lastSentMessage {
                // Set up a pong timeout, i.e., if a pong isn't received in time, reconnect
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { // 5 seconds pong timeout, tweak as necessary
                    if self.connectionState == .connected {
                        print("No pong received in time, reconnecting...")
                        self.disconnect()
                        self.connect()
                    }
                }
            }
            self.socket.write(ping: Data())
        }
    }
    
    private func awaitPongThenSendMessage() {
        onPongReceived = { [weak self] in
            if let message = self?.lastSentMessage {
                self?.socket.write(string: message)
                self?.lastSentMessage = nil // Clear the stored message after sending
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
        let frameworkBundle = Bundle(for: type(of: self))
        
        guard let path = frameworkBundle.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let token = dict["HomeAssistantAccessToken"] as? String else {
            print("Failed to retrieve access token from Secrets.plist.")
            return nil
        }
        
        return token
    }
    
    private func authenticate() {
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
        lastSentMessage = message
        socket.write(ping: Data()) // Send ping before message
        awaitPongThenSendMessage()
    }
    public func handleEventMessage(_ message: HAEventData) {
        // Process or forward event to other handlers
        for handler in eventMessageHandlers {
            handler.handleEventMessage(message)
        }
    }
}

private func determineWebSocketMessageType(data: Data) -> WebSocketMessageType {
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
              // Handle default case
              return .result
          }
      }
      return .result
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
                 }
             }
            
        case .binary(let data):
            print("Received binary data:", data)
        case .ping:
            print("Received ping.")
        case .pong:
            print("Received pong.")
            onPongReceived?() // Execute the closure
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
}
