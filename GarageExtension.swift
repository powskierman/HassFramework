//
//  GarageExtension.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-11.
//

import Foundation
import Starscream

public extension HassWebSocket {

    func setEntityState(entityId: String, newState: String) {
        messageId += 1
        
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
            "id": messageId,
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

    // ... Add any other methods specific to the garage functionality here ...

}
