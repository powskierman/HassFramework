//
//  HassProtocols.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation

public protocol EventMessageHandler {
    func handleEventMessage(_ message: HAEventData)
}
