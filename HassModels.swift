//
//  HassModels.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation

public struct HAContext: Decodable {
    let id: String
    let parentId: String?
    let userId: String?
}

public struct HAAttributes: Decodable {
    public let friendlyName: String
    // Add any other attributes as needed
}

public struct HAState: Decodable {
    public let entityId: String
    public let state: String
    public let attributes: HAAttributes
    public let lastChanged: String
    public let context: HAContext
    // If you also need the `last_updated`, you can add it here
}

public struct HAEventData: Decodable {
    public let entityId: String
    public let oldState: HAState
    public let newState: HAState
}
