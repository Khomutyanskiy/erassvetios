//
//  User+Display.swift
//  erassvet
//

import FirebaseAuth

extension User {
    var emailOrFallback: String {
        email ?? "Без email"
    }

    var displayNameOrFallback: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        if let email {
            let local = email.split(separator: "@").first.map(String.init) ?? email
            return local
        }
        return "Пользователь"
    }

    /// Two-letter initials derived from displayName, or from the email's local part.
    var initials: String {
        if let displayName, !displayName.isEmpty {
            let parts = displayName
                .split(separator: " ")
                .compactMap { $0.first }
                .map(String.init)
            if parts.count >= 2 {
                return (parts[0] + parts[1]).uppercased()
            }
            if let first = parts.first {
                return first.uppercased()
            }
        }
        if let email {
            let local = email.split(separator: "@").first.map(String.init) ?? email
            let parts = local
                .split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" })
                .compactMap { $0.first }
                .map(String.init)
            if parts.count >= 2 {
                return (parts[0] + parts[1]).uppercased()
            }
            return String(local.prefix(2)).uppercased()
        }
        return "??"
    }
}
