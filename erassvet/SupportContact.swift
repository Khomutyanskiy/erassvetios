//
//  SupportContact.swift
//  erassvet
//

import SwiftUI
import FirebaseFirestore

struct SupportContact: Identifiable {
    let id: String
    let type: String
    let title: String
    let value: String
    let urlString: String
    let order: Int

    init?(id: String, data: [String: Any]) {
        guard
            let type = data["type"] as? String,
            let title = data["title"] as? String,
            let value = data["value"] as? String
        else { return nil }

        self.id = id
        self.type = type
        self.title = title
        self.value = value
        self.urlString = (data["url"] as? String) ?? SupportContact.defaultURL(type: type, value: value)
        self.order = (data["order"] as? Int) ?? 0
    }

    private static func defaultURL(type: String, value: String) -> String {
        switch type.lowercased() {
        case "email":
            return "mailto:\(value)"
        case "telegram":
            return "https://t.me/\(value.hasPrefix("@") ? String(value.dropFirst()) : value)"
        case "whatsapp":
            let digits = value.filter(\.isNumber)
            return "https://wa.me/\(digits)"
        case "phone":
            return "tel:\(value.filter { $0.isNumber || $0 == "+" })"
        default:
            return value
        }
    }

    var icon: String {
        switch type.lowercased() {
        case "email": return "envelope.fill"
        case "telegram": return "paperplane.fill"
        case "whatsapp": return "message.fill"
        case "max": return "bubble.left.and.bubble.right.fill"
        case "phone": return "phone.fill"
        default: return "link"
        }
    }

    var tint: Color {
        switch type.lowercased() {
        case "email": return AppTheme.accent
        case "telegram": return Color(hex: "2AABEE")
        case "whatsapp": return Color(hex: "25D366")
        case "max": return Color(hex: "8E6EF0")
        case "phone": return Color(hex: "3FBF7F")
        default: return AppTheme.textSecondary
        }
    }
}
