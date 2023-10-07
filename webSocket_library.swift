//
//  ContentView.swift
//  websocket_test2
//
//  Created by Michel Lapointe on 2023-09-27.
//

import Foundation
import Starscream

public class HomeAssistantWebSocket {
    
    // Shared instance
    public static let shared = HomeAssistantWebSocket()
    
    private var socket: WebSocket
    private let serverURL: String = "ws://192.168.0.14:8123/api/websocket"
    private var id : Int
    private var isAuthenticated = false
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onEventReceived: ((String) -> Void)?

    // Make the initializer private
    private init() {
        self.id = 0
        var request = URLRequest(url: URL(string: serverURL)!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
    }

    
    // Connect to Home Assistant
    func connect() {
        print("Attempting to connect to WebSocket...")
        socket.connect()
    }
   
    private func getAccessToken() -> String? {
        let frameworkBundle = Bundle(for: type(of: self))
        
        guard let path = frameworkBundle.path(forResource: "Secrets", ofType: "plist") else {
            print("Failed to find Secrets.plist in the framework bundle.")
            return nil
        }
        
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Failed to read the contents of Secrets.plist as a dictionary.")
            return nil
        }
        
        guard let token = dict["HomeAssistantAccessToken"] as? String else {
            print("Failed to retrieve the 'HomeAssistantAccessToken' key from the dictionary.")
            return nil
        }
        print("Successfully retrieved access token from Secrets.plist")
        return token
    }

        func authenticate() {
            guard let accessToken = getAccessToken() else {
                print("Failed to retrieve access token.")
                return
            }

            let authMessage = [
                "type": "auth",
                "access_token": accessToken
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: authMessage, options: []),
                let jsonString = String(data: data, encoding: .utf8) {
                print("Authenticating with message:", jsonString)
                socket.write(string: jsonString)
            } else {
                print("Failed to serialize authentication message.")
            }
        }
    
    func subscribeToEvents() {
        id += 1
        let subscribeMessage: [String: Any] = [
            "id": id,
            "type": "subscribe_events",
            "event_type": "state_changed"
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: subscribeMessage, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                self.sendTextMessage(jsonString)
            }
        } catch {
            print("Failed to encode message:", error)
        }
    }

    func sendTextMessage(_ message: String) {
        socket.write(string: message)
    }

    // Close the connection
    func disconnect() {
        socket.disconnect()
    }
}

extension HomeAssistantWebSocket: WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(_):
            onConnected?()
            print("WebSocket connected")
            
            // Log before introducing delay for authentication
            //           print("Preparing to send authentication in 1 second...")
            //           DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // 1-second delay
            //                self.authenticate(with: client)
            //            }
            
        case .text(let text):
            print("Received text:", text)
            
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let type = json["type"] as? String {
                switch type {
                case "auth_required":
                    print("Authentication request detected. Authenticating...")
                    if !self.isAuthenticated {
                        self.authenticate()
                    }
                case "auth_ok":
                    print("Authentication successful!")
                    self.isAuthenticated = true
                case "auth_invalid":
                    if let message = json["message"] as? String {
                        print("Authentication failed with message:", message)
                    } else {
                        print("Authentication failed with no specific message.")
                    }
                default:
                    onEventReceived?(text)
                    print("Received unknown message type:", type)
                }
                // Notify the event through the callback instead of calling `websocketManager`
                onEventReceived?(text)
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
            print("Error:", error ?? "Unknown Error")
        case .peerClosed:
            print("Peer closed the WebSocket")
        case .disconnected(_, _):
            onDisconnected?()
            print("WebSocket disconnected")
        }
    }
}
