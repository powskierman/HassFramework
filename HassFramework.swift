//
//  HassFramework.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2024-06-09.
//

import Foundation

public class HassFramework {
    public static let shared = HassFramework()
    
    private init() {}
    
    // Access points for other components
    public let restClient = HassRestClient.shared
    public let webSocket = HassWebSocket.shared

    // Register device token method
    public func registerDeviceToken(_ deviceToken: String) {
        restClient.sendDeviceToken(deviceToken) { result in
            switch result {
            case .success():
                print("Device token registered successfully.")
            case .failure(let error):
                print("Failed to register device token: \(error)")
            }
        }
    }

    public func handleIncomingNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle the incoming notification
        // Parse the notification payload and take appropriate action
    }
}
