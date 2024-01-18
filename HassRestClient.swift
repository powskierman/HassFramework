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
        self.session = URLSession(configuration: .default)

        // Fetch the server URL
        guard let serverURLString = HassWebSocket.shared.getServerURLFromSecrets(),
              let url = URL(string: serverURLString) else {
            fatalError("Invalid or missing server URL.")
        }
        self.baseURL = url

        // Assume the auth token is stored in Secrets.plist and fetched similarly
        guard let token = HassWebSocket.shared.getAccessToken() else {
            fatalError("Invalid or missing auth token.")
        }
        self.authToken = token
    }

    func performRequest<T: Decodable>(endpoint: String,
                                      method: String = "GET",
                                      body: Data? = nil,
                                      completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            completion(.failure(HassError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        let task = session.dataTask(with: request) { data, response, error in
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
    func fetchDeviceState(deviceId: String, completion: @escaping (Result<DeviceState, Error>) -> Void) {
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

    // ... Other methods as needed
}

// Custom Error Types
enum HassError: Error {
    case invalidURL
    case noData
    case encodingError
}

// Models for Decoding API Responses
struct DeviceState: Decodable {
    // Define properties according to Home Assistant's API response
}

public struct DeviceCommand: Encodable {
    public let service: String
    public let entityId: String
    
    public init(service: String, entityId: String) {
        self.service = service
        self.entityId = entityId
    }
}

public struct CommandResponse: Decodable {
    // Define properties for command response
}

extension HassRestClient {
    // Fetch the state of a specified entity
    public func fetchState(entityId: String, completion: @escaping (Result<HAEntity, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("states/\(entityId)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(HAError.dataUnavailable))
                return
            }

            do {
                let entity = try JSONDecoder().decode(HAEntity.self, from: data)
                completion(.success(entity))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    // Modify the state of a specified entity
    public func changeState(entityId: String, newState: String, completion: @escaping (Result<HAEntity, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("states/\(entityId)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["state": newState]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(HAError.dataUnavailable))
                return
            }

            do {
                let entity = try JSONDecoder().decode(HAEntity.self, from: data)
                completion(.success(entity))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }
}
