//
//  HassMessageTypes.swift
//  HassFramework
//
//  Created by Michel Lapointe on 2023-10-15.
//

import Foundation
public enum WebSocketMessageType {
    case authRequired
    case authOk
    case result
    case event
}
