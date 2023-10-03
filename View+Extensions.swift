//
//  View+Extensions.swift
//  websocket_test2
//
//  Created by Michel Lapointe on 2023-09-29.
//

import SwiftUI

extension View {
    func bottomSafeAreaInsets() -> CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return 0
        }
        
        let window = scene.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
}
