//
//  AppUser.swift
//  erassvet
//

import Foundation
import FirebaseFirestore

/// A registered user's profile document, as seen from the admin panel
/// ("users/{uid}" in Firestore). Not to be confused with FirebaseAuth's
/// `User`, which represents the currently signed-in account only.
struct AppUser: Identifiable, Hashable {
    static func == (lhs: AppUser, rhs: AppUser) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let email: String
    let displayName: String
    let role: String
    let photoURL: String?
    let createdAt: Date?
    /// Set by an admin from the "Жалобы" queue (or directly here) — a
    /// banned user is signed out client-side in real time, see
    /// `AuthViewModel.observeUserDocument`.
    let isBanned: Bool

    init(id: String, data: [String: Any]) {
        self.id = id
        self.email = data["email"] as? String ?? ""
        self.displayName = data["displayName"] as? String ?? ""
        self.role = data["role"] as? String ?? "user"
        self.photoURL = data["photoURL"] as? String
        self.isBanned = data["isBanned"] as? Bool ?? false
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }

    var isAdmin: Bool { role == "admin" }

    /// Name shown in the list — falls back to the email's local part, then a placeholder.
    var displayNameOrFallback: String {
        if !displayName.isEmpty { return displayName }
        if let atIndex = email.firstIndex(of: "@") { return String(email[..<atIndex]) }
        return "Без имени"
    }

    var initials: String {
        let source = !displayName.isEmpty ? displayName : email
        let parts = source
            .split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" || $0 == "-" || $0 == "@" })
            .compactMap { $0.first }
            .map(String.init)
        if parts.count >= 2 { return (parts[0] + parts[1]).uppercased() }
        if let first = parts.first { return first.uppercased() }
        return "?"
    }

    var joinedDateText: String {
        guard let createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: createdAt)
    }
}
