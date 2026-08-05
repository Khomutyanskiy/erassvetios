//
//  ViewerIdentity.swift
//  erassvet
//

import Foundation

/// A stable anonymous identifier for this device/install, persisted in
/// UserDefaults. Used to dedupe unique ad views without requiring auth.
enum ViewerIdentity {
    private static let key = "erassvet.viewerId"

    static var id: String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
