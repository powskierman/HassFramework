//
//  HassRestClient.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-12-31.
//

import Foundation
import Combine

public class HassRestClient {
    public static let shared = HassRestClient()
    
    private let baseURL: URL
    private let session: URLSession
    private let authToken: String
    
    private init() {
        let secrets = HassRestClient.loadSecrets()
        guard let serverURLString = secrets?["RESTURL"] as? String,
              let token = secrets?["authToken"] as? String else {
            fatalError("Invalid or missing URL or auth token in Secrets.plist.")
        }
        
        self.baseURL = URL(string: serverURLString)!
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
        
        print("Loaded Secrets from Secrets.plist: \(dictionary)")
        return dictionary
    }
    
    public func performRequest(endpoint: String, method: String, body: Data?) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        let adjustedEndpoint = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: adjustedEndpoint)
        request.httpMethod = method
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            request.httpBody = body
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { $0 as URLError }
            .eraseToAnyPublisher()
    }
    
    
    // Add specific methods for various Home Assistant actions
    
    // Example: Fetching the state of a device
 
        public func fetchDeviceState(deviceId: String) -> AnyPublisher<DeviceState, Error> {
            let endpoint = "api/states/\(deviceId)"
            
            return performRequest(endpoint: endpoint, method: "GET", body: nil)
                .tryMap { output -> Data in
                    guard let httpResponse = output.response as? HTTPURLResponse,
                          200...299 ~= httpResponse.statusCode else {
                        throw URLError(.badServerResponse)
                    }
                    return output.data
                }
                .decode(type: DeviceState.self, decoder: JSONDecoder())
                .eraseToAnyPublisher()
        }
    
    
    public func sendCommandToDevice<T: Encodable, R: Decodable>(deviceId: String, command: T, endpoint: String) -> AnyPublisher<R, Error> {
        guard let body = try? JSONEncoder().encode(command) else {
            return Fail(error: HassError.encodingError).eraseToAnyPublisher()
        }
        
        return performRequest(endpoint: endpoint, method: "POST", body: body)
            .tryMap { output -> Data in
                // Ensure the response is successful before attempting to decode
                guard let httpResponse = output.response as? HTTPURLResponse,
                      200...299 ~= httpResponse.statusCode else {
                    throw URLError(.badServerResponse)
                }
                return output.data
            }
            .decode(type: R.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
        public func callScript(scriptName: String) -> AnyPublisher<Void, Error> {
            let endpoint = "api/services/script/\(scriptName)"
            // If bodyData is not needed for the script, this can remain nil
            let bodyData: Data? = nil
            
            return performRequest(endpoint: endpoint, method: "POST", body: bodyData)
                .tryMap { output in
                    guard let httpResponse = output.response as? HTTPURLResponse,
                          200...299 ~= httpResponse.statusCode else {
                        throw URLError(.badServerResponse)
                    }
                    // Simply return Void since you're only interested in the success of the HTTP request
                    return ()
                }
                .mapError { $0 as Error } // Ensure any URLError is properly cast to Error
                .eraseToAnyPublisher()
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
    
        public func changeState(entityId: String, newState: Int) -> AnyPublisher<HAEntity, Error> {
            let endpoint = "states/\(entityId)"
            // Constructing the JSON body
            let body = ["state": String(newState)]
            do {
                let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
                
                // Adjust the call to performRequest and ensure it's prepared for decoding
                return performRequest(endpoint: endpoint, method: "POST", body: bodyData)
                    .tryMap { output -> Data in
                        // Verify the HTTP response status before proceeding
                        guard let httpResponse = output.response as? HTTPURLResponse,
                              200...299 ~= httpResponse.statusCode else {
                            throw URLError(.badServerResponse)
                        }
                        return output.data // Directly return the Data component for decoding
                    }
                    .decode(type: HAEntity.self, decoder: JSONDecoder()) // Now decode the Data to HAEntity
                    .eraseToAnyPublisher()
            } catch {
                // Handle JSON encoding error by returning a Fail publisher
                return Fail(error: error).eraseToAnyPublisher()
            }
        }
    
        public func fetchState(entityId: String) -> AnyPublisher<HAEntity, Error> {
            let endpoint = "states/\(entityId)"
            
            return performRequest(endpoint: endpoint, method: "GET", body: nil)
                .tryMap { output -> Data in
                    // Ensure the response is successful before attempting to decode
                    guard let httpResponse = output.response as? HTTPURLResponse,
                          200...299 ~= httpResponse.statusCode else {
                        throw URLError(.badServerResponse)
                    }
                    return output.data
                }
                .decode(type: HAEntity.self, decoder: JSONDecoder())
                .catch { error -> AnyPublisher<HAEntity, Error> in
                    // Check if the error is a decoding error indicating the entity is not found
                    if let decodingError = error as? DecodingError,
                       decodingError.isEntityNotFoundError() {
                        // Handle the specific case of entity not found
                        print("[HassRestClient] Entity not found: \(entityId)")
                        return Fail(error: HassError.entityNotFound).eraseToAnyPublisher()
                    } else {
                        // Forward other errors as is
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                }
                .eraseToAnyPublisher()
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
