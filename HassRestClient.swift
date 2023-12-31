//
//  HassRestClient.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-12-31.
//

import Foundation

class HassRestClient {
    private let baseURL: URL
    private let session: URLSession
    private let authToken: String

    init(baseURL: URL, authToken: String) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.session = URLSession(configuration: .default)
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
    func sendCommandToDevice(deviceId: String, command: DeviceCommand, completion: @escaping (Result<CommandResponse, Error>) -> Void) {
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

struct DeviceCommand: Encodable {
    let service: String
    // Define other command properties
}

struct CommandResponse: Decodable {
    // Define properties for command response
}

