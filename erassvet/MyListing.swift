//
//  MyListing.swift
//  erassvet
//

import SwiftUI

enum ListingStatus {
    case active
    case pending
    case expired

    var title: String {
        switch self {
        case .active: return "Активно"
        case .pending: return "На проверке"
        case .expired: return "Истекло"
        }
    }

    var color: Color {
        switch self {
        case .active: return Color(hex: "3FBF7F")
        case .pending: return Color(hex: "C98A3D")
        case .expired: return AppTheme.textSecondary
        }
    }
}

struct MyListing: Identifiable {
    let id = UUID()
    let title: String
    let status: ListingStatus
    let priceText: String
    let views: Int
    let imageSystemName: String

    static let sample: [MyListing] = [
        MyListing(title: "Кирпич М-150, поддон", status: .active, priceText: "18 500 ₽", views: 47, imageSystemName: "shippingbox.fill"),
        MyListing(title: "Аренда лесов строительных", status: .pending, priceText: "2 200 ₽/день", views: 0, imageSystemName: "building.2.fill"),
        MyListing(title: "Бетономешалка б/у", status: .expired, priceText: "15 000 ₽", views: 23, imageSystemName: "wrench.and.screwdriver.fill")
    ]
}
