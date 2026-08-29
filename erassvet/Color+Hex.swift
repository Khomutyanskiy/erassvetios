//
//  Color+Hex.swift
//  erassvet
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Round-trips a `ColorPicker`-selected `Color` back to a hex string for
    /// storage in Firestore (`CategoryStyleEditorView`). Resolved against the
    /// app's fixed dark theme, so this stays consistent across devices.
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "%02X%02X%02X",
            Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255))
        )
    }

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

    /// Categories are admin-managed (see `CategoriesViewModel`) — an admin
    /// can add new ones at any time — so instead of a fixed name→color map
    /// (which would silently fall back to plain accent-blue for anything not
    /// hand-listed, as happened with "Подработка"), every category gets a
    /// color deterministically picked from `categoryPalette` by hashing its
    /// title. Same title always maps to the same color, and every category,
    /// present or future, gets a distinct-looking chip automatically.
    private static let categoryPalette: [Color] = [
        Color(hex: "3D7DFF"),
        Color(hex: "3FBF7F"),
        Color(hex: "C98A3D"),
        Color(hex: "8E6EF0"),
        Color(hex: "3DBFBF"),
        Color(hex: "F0956B"),
        Color(hex: "E85D9E"),
        Color(hex: "C9C93D"),
        Color(hex: "5D9EE8"),
        Color(hex: "BF5D3D"),
        Color(hex: "6EE895"),
        Color(hex: "A03DBF")
    ]

    @MainActor
    static func colorForCategory(_ category: String) -> Color {
        guard !category.isEmpty else { return accent }
        if let hex = CategoryStyleStore.shared.colorHex(for: category) {
            return Color(hex: hex)
        }
        let hash = category.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        let index = abs(hash) % categoryPalette.count
        return categoryPalette[index]
    }

    /// One distinct color per deal type ("Предлагаю"/"Требуется"/"Даром"),
    /// used both for the badge on ad cards and the filter chips in the feed.
    static let dealTypeColors: [AdDealType: Color] = [
        .offer: Color(hex: "3D7DFF"),
        .request: Color(hex: "F0956B"),
        .free: Color(hex: "3FBF7F")
    ]
}
