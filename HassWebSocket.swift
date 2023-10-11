//
//  ContentView.swift
//  websocket_test2
//
//  Created by Michel Lapointe on 2023-09-27.
//

import Foundation
import Starscream

public class HassWebSocket: ObservableObject {
    
    // Shared instance
    public static let shared = HassWebSocket()

    @Published var connectionState: ConnectionState = .disconnected
    
    private var socket: WebSocket
    private var serverURL: String? {
         get {
             let frameworkBundle = Bundle(for: type(of: self))
             guard let path = frameworkBundle.path(forResource: "Secrets", ofType: "plist") else {
                 print("Failed to find Secrets.plist in the framework bundle.")
                 return nil
             }
             
             guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
                 print("Failed to read the contents of Secrets.plist as a dictionary.")
                 return nil
             }
             
             guard let url = dict["HomeAssistantServerURL"] as? String else {
                 print("Failed to retrieve the 'HomeAssistantServerURL' key from the dictionary.")
                 return nil
             }
             return url
         }
     }
    private var id : Int = 0
    private var isAuthenticated = false
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onEventReceived: ((String) -> Void)?
    private var pingTimer: Timer?
    private let pingInterval: TimeInterval = 60.0 // Ping every 60 seconds


    private static func fetchServerURL() -> URL? {
        let frameworkBundle = Bundle(for: HassWebSocket.self)
        
        guard let path = frameworkBundle.path(forResource: "Secrets", ofType: "plist") else {
            print("Failed to find Secrets.plist in the framework bundle.")
            return nil
        }
        
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Failed to read the contents of Secrets.plist as a dictionary.")
            return nil
        }
        
        guard let serverURLString = dict["HomeAssistantServerURL"] as? String else {
            print("Failed to retrieve the 'HomeAssistantServerURL' key from the dictionary.")
            return nil
        }
        
        return URL(string: serverURLString)
    }

    private init() {
        self.id = 0
        
        guard let requestURL = HassWebSocket.fetchServerURL() else {
            fatalError("Failed to retrieve server URL from Secrets.plist or the URL is malformed.")
        }
        
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
    }

    
    // Connect to Home Assistant
    public func connect() {
         print("Attempting to connect to WebSocket...")
         socket.connect()

         // Start the ping timer when we attempt to connect
         startPingTimer()
     }
    private func startPingTimer() {
         // Schedule a timer to send ping messages
         pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
             self.socket.write(ping: Data()) // Sending a ping message
         }
     }

     private func stopPingTimer() {
         pingTimer?.invalidate()
         pingTimer = nil
     }

     public func disconnect() {
         // Stop the ping timer when we intentionally disconnect
         stopPingTimer()
         socket.disconnect()
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

       private func authenticate() {
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
    
   public func subscribeToEvents() {
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

    public func sendTextMessage(_ message: String) {
        socket.write(string: message)
    }

    func setEntityState(entityId: String, newState: String) {
        id += 1
        
        print("Setting entity state for entityId:", entityId, ", newState:", newState)
        
        var domain: String
        var service: String
        
        if entityId.starts(with: "switch.") {
            domain = "switch"
            service = newState  // newState would be 'toggle' for a switch
        } else {
            // Handle other entity types as needed
            domain = "homeassistant"
            service = "turn_\(newState)"
        }
        
        let command: [String: Any] = [
            "id": id,
            "type": "call_service",
            "domain": domain,
            "service": service,
            "service_data": [
                "entity_id": entityId
            ]
        ]
        
        print("Constructed command:", command)

        do {
            let data = try JSONSerialization.data(withJSONObject: command, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Sending JSON command:", jsonString)
                self.sendTextMessage(jsonString)
            } else {
                print("Failed to convert data to string.")
            }
        } catch {
            print("Failed to encode message:", error)
        }
    }
}

extension HassWebSocket: WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(_):
            connectionState = .connected
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
