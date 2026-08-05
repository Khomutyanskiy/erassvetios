//
//  Color+Hex.swift
//  erassvet
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum AppTheme {
    static let background = Color(hex: "0A1120")
    static let card = Color(hex: "121B2E")
    static let cardBorder = Color(hex: "223052")
    static let accent = Color(hex: "3D7DFF")
    static let gold = Color(hex: "F0C419")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8A93A6")
    static let searchBarBackground = Color(hex: "121B2E")

    static let categoryColors: [String: Color] = [
        "Строительство": Color(hex: "3D7DFF"),
        "Транспорт": Color(hex: "3FBF7F"),
        "Продукты": Color(hex: "C98A3D"),
        "Обучение": Color(hex: "8E6EF0"),
        "Электроника": Color(hex: "3DBFBF")
    ]

    /// One distinct color per deal type ("Предлагаю"/"Требуется"/"Даром"),
    /// used both for the badge on ad cards and the filter chips in the feed.
    static let dealTypeColors: [AdDealType: Color] = [
        .offer: Color(hex: "3D7DFF"),
        .request: Color(hex: "F0956B"),
        .free: Color(hex: "3FBF7F")
    ]
}
