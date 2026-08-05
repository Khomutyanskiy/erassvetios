//
//  UserContacts.swift
//  erassvet
//

import Foundation
import SwiftUI

struct CustomContact: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var label: String = ""
    var value: String = ""
}

struct UserContacts: Equatable {
    var email: String = ""
    var phone: String = ""
    var telegram: String = ""
    var whatsapp: String = ""
    var max: String = ""
    var other: [CustomContact] = []

    func toDictionary() -> [String: Any] {
        [
            "email": email,
            "phone": phone,
            "telegram": telegram,
            "whatsapp": whatsapp,
            "max": max,
            "other": other
                .filter { !$0.label.trimmingCharacters(in: .whitespaces).isEmpty || !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { ["label": $0.label, "value": $0.value] }
        ]
    }

    static func from(_ data: [String: Any]?, fallbackEmail: String) -> UserContacts {
        var result = UserContacts()
        result.email = (data?["email"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackEmail
        result.phone = data?["phone"] as? String ?? ""
        result.telegram = data?["telegram"] as? String ?? ""
        result.whatsapp = data?["whatsapp"] as? String ?? ""
        result.max = data?["max"] as? String ?? ""
        if let otherArray = data?["other"] as? [[String: Any]] {
            result.other = otherArray.map {
                CustomContact(label: $0["label"] as? String ?? "", value: $0["value"] as? String ?? "")
            }
        }
        return result
    }
}

/// A single displayable, tappable contact — built from a filled-in field
/// of `UserContacts`. `id` is a stable key ("email", "phone", "telegram",
/// "whatsapp", "max", or "custom_<index>") used to persist which contacts
/// a seller chose to show on a given ad.
struct ContactItem: Identifiable, Equatable {
    let id: String
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let urlString: String
}

extension UserContacts {
    /// All non-empty contacts, in a fixed display order.
    var items: [ContactItem] {
        var result: [ContactItem] = []

        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        if !trimmedEmail.isEmpty {
            result.append(ContactItem(id: "email", icon: "envelope.fill", tint: AppTheme.accent, title: "Email", value: trimmedEmail, urlString: "mailto:\(trimmedEmail)"))
        }

        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        if !trimmedPhone.isEmpty {
            let digits = trimmedPhone.filter { $0.isNumber || $0 == "+" }
            result.append(ContactItem(id: "phone", icon: "phone.fill", tint: Color(hex: "3FBF7F"), title: "Телефон", value: trimmedPhone, urlString: "tel:\(digits)"))
        }

        let trimmedTelegram = telegram.trimmingCharacters(in: .whitespaces)
        if !trimmedTelegram.isEmpty {
            let handle = trimmedTelegram.hasPrefix("@") ? String(trimmedTelegram.dropFirst()) : trimmedTelegram
            result.append(ContactItem(id: "telegram", icon: "paperplane.fill", tint: Color(hex: "2AABEE"), title: "Telegram", value: trimmedTelegram, urlString: "https://t.me/\(handle)"))
        }

        let trimmedWhatsapp = whatsapp.trimmingCharacters(in: .whitespaces)
        if !trimmedWhatsapp.isEmpty {
            let digits = trimmedWhatsapp.filter(\.isNumber)
            result.append(ContactItem(id: "whatsapp", icon: "message.fill", tint: Color(hex: "25D366"), title: "WhatsApp", value: trimmedWhatsapp, urlString: "https://wa.me/\(digits)"))
        }

        let trimmedMax = max.trimmingCharacters(in: .whitespaces)
        if !trimmedMax.isEmpty {
            result.append(ContactItem(id: "max", icon: "bubble.left.and.bubble.right.fill", tint: Color(hex: "8E6EF0"), title: "MAX", value: trimmedMax, urlString: trimmedMax))
        }

        for (index, custom) in other.enumerated() {
            let trimmedValue = custom.value.trimmingCharacters(in: .whitespaces)
            guard !trimmedValue.isEmpty else { continue }
            let label = custom.label.trimmingCharacters(in: .whitespaces)
            result.append(ContactItem(id: "custom_\(index)", icon: "link", tint: AppTheme.textSecondary, title: label.isEmpty ? "Контакт" : label, value: trimmedValue, urlString: trimmedValue))
        }

        return result
    }

    /// Returns a copy containing only the contacts whose stable key is in `keys` —
    /// used to build the subset of contacts a seller chose to show on an ad.
    func filtered(keys: Set<String>) -> UserContacts {
        var result = UserContacts()
        for item in items where keys.contains(item.id) {
            switch item.id {
            case "email": result.email = email.trimmingCharacters(in: .whitespaces)
            case "phone": result.phone = phone.trimmingCharacters(in: .whitespaces)
            case "telegram": result.telegram = telegram.trimmingCharacters(in: .whitespaces)
            case "whatsapp": result.whatsapp = whatsapp.trimmingCharacters(in: .whitespaces)
            case "max": result.max = max.trimmingCharacters(in: .whitespaces)
            default:
                if item.id.hasPrefix("custom_"), let idx = Int(item.id.dropFirst("custom_".count)), other.indices.contains(idx) {
                    result.other.append(other[idx])
                }
            }
        }
        return result
    }
}
