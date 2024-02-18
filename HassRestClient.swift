//
//  HassRestClient.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-12-31.
//

import Foundation

public class HassRestClient {
    private let baseURL: URL
    private let session: URLSession
    private let authToken: String
    
    public init() {
        let secrets = HassRestClient.loadSecrets()
        guard let serverURLString = secrets?["RESTURL"] as? String,
              let _ = secrets?["WSURL"] as? String, // WebSocket URL, if needed
              let token = secrets?["authToken"] as? String else {
            print("Error: Invalid or missing URL or auth token in Secrets.plist.")
            fatalError("Invalid or missing URL or auth token in Secrets.plist.")
        }
        
        // Use REST URL for baseURL
        self.baseURL = URL(string: serverURLString)!
        // WebSocket URL can be used as needed, perhaps as a separate property
        // let wsURL = URL(string: wsURLString)!
        
        self.authToken = token
        self.session = URLSession(configuration: .default)
    }
    
    private static func loadSecrets() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist") else {
            print("Error: Secrets.plist file not found.")
            return nil
        }
        
        guard let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Error: Unable to read or cast Secrets.plist as a dictionary.")
            return nil
        }
        
        // Print the retrieved data for debugging
        print("Loaded Secrets from Secrets.plist: \(dictionary)")
        return dictionary
    }
    
    func performRequest<T: Decodable>(endpoint: String,
                                      method: String = "GET",
                                      body: Data? = nil,
                                      completion: @escaping (Result<T, Error>) -> Void) {
        // Construct the full URL by appending the endpoint to the baseURL
        let fullURL = baseURL.appendingPathComponent(endpoint)
        
        var request = URLRequest(url: fullURL)
        request.httpMethod = method
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("[HassRestClient] Response Status Code: \(httpResponse.statusCode)")
            }
            if let data = data {
                let rawJSON = String(decoding: data, as: UTF8.self)
                print("[HassRestClient] Raw JSON Response: \(rawJSON)")
            }
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(HassError.noData))
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    
    // Add specific methods for various Home Assistant actions
    
    // Example: Fetching the state of a device
    public func fetchDeviceState(deviceId: String, completion: @escaping (Result<DeviceState, Error>) -> Void) {
        performRequest(endpoint: "api/states/\(deviceId)", completion: completion)
    }
    
    // Example: Sending a command to a device
    public func sendCommandToDevice(deviceId: String, command: DeviceCommand, completion: @escaping (Result<CommandResponse, Error>) -> Void) {
        let endpoint = "api/services/\(command.service)"
        guard let body = try? JSONEncoder().encode(command) else {
            completion(.failure(HassError.encodingError))
            return
        }
        performRequest(endpoint: endpoint, method: "POST", body: body, completion: completion)
    }
    
    public func callScript(entityId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let endpoint = "services/script/turn_on"
        let body: [String: Any] = ["entity_id": entityId]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(.failure(HassError.encodingError))
            return
        }
        
        performRequest(endpoint: endpoint, method: "POST", body: bodyData) { (result: Result<[ScriptResponse], Error>) in
            switch result {
            case .success(_):
                // Since we only care about the success of the call, not the response data,
                // we just pass success with Void (nothing) to the completion handler.
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // ... Other methods as needed
    
    // Models for Decoding API Responses
    public struct DeviceState: Decodable {
        // Define properties according to Home Assistant's API response
    }
    
    public struct DeviceCommand: HassCommand, Encodable {
        public var endpoint: String {
            "api/services/\(service)"
        }
        public var method: String {
            "POST"
        }
        public var body: Data? {
            // Since we're implementing `Encodable` manually, `body` isn't used for encoding anymore.
            // You might adjust its usage based on your actual use case.
            return nil
        }
        
        public var service: String
        public var entityId: String
        public var data: AnyEncodable
        
        public init<T: Encodable>(service: String, entityId: String, data: T) {
            self.service = service
            self.entityId = entityId
            self.data = AnyEncodable(data)
        }
        
        // Explicit `Encodable` conformance
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(service, forKey: .service)
            try container.encode(entityId, forKey: .entityId)
            
            // Since `data` is `AnyEncodable` which conforms to `Encodable`, it can encode itself.
            // However, you need to ensure that it encodes into the same container as `DeviceCommand`.
            // This might require adjusting `AnyEncodable` to properly encode its wrapped value.
            try data.encode(to: encoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case service
            case entityId = "entity_id"
            // You don't need a coding key for `data` as it encodes itself.
        }
    }


    
    /// A type-erasing wrapper to enable `Encodable` types to be used for `data`.
    
    public struct AnyEncodable: Encodable {
        private let encodeFunc: (Encoder) throws -> Void
        
        public init<T: Encodable>(_ encodable: T) {
            self.encodeFunc = { try encodable.encode(to: $0) }
        }
        
        public func encode(to encoder: Encoder) throws {
            try encodeFunc(encoder)
        }
    }

    
    public struct CommandResponse: Decodable {
        // Define properties for command response
    }
    
    public func changeState(entityId: String, newState: Int, completion: @escaping (Result<HAEntity, Error>) -> Void) {
        let endpoint = "states/\(entityId)"
        // Assuming newState is a temperature, it might need to be sent as a string.
        let body = ["state": String(newState)]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(.failure(HassError.encodingError))
            return
        }
        performRequest(endpoint: endpoint, method: "POST", body: bodyData, completion: completion)
    }
}
    extension HassRestClient {
        // Fetch the state of a specified entity
        
        public func fetchState(entityId: String, completion: @escaping (Result<HAEntity, Error>) -> Void) {
            let endpoint = "states/\(entityId)"
            performRequest(endpoint: endpoint) { (result: Result<HAEntity, Error>) in
                switch result {
                case .success(let entity):
                    completion(.success(entity))
                case .failure(let error):
                    if let decodingError = error as? DecodingError,
                       decodingError.isEntityNotFoundError() {
                        // Handle the case where the entity is not found
                        print("[HassRestClient] Entity not found: \(entityId)")
                        completion(.failure(HassError.entityNotFound))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
extension DecodingError {
    func isEntityNotFoundError() -> Bool {
        switch self {
        case .keyNotFound(let key, _):
            // If the missing key is `entity_id`, we infer that the entity might not be found.
            return key.stringValue == "entity_id"
        default:
            // For other types of decoding errors, return false.
            return false
        }
    }
}
