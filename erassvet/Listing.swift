//
//  Listing.swift
//  erassvet
//

import Foundation

struct Listing: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let priceText: String
    let timeAgo: String
    let imageSystemName: String

    static let sample: [Listing] = [
        Listing(title: "Кирпич М-150 поддон", category: "Строительство", priceText: "18 500 ₽", timeAgo: "15 мин назад", imageSystemName: "shippingbox.fill"),
        Listing(title: "Toyota Camry 2019, 2.5", category: "Транспорт", priceText: "1 350 000 ₽", timeAgo: "28 мин назад", imageSystemName: "car.fill"),
        Listing(title: "Домашний сыр Гауда 500г", category: "Продукты", priceText: "650 ₽", timeAgo: "1 ч назад", imageSystemName: "leaf.fill"),
        Listing(title: "Репетитор по математике ЕГЭ", category: "Обучение", priceText: "Договорная", timeAgo: "2 ч назад", imageSystemName: "book.fill"),
        Listing(title: "iPhone 14 Pro, 256 ГБ", category: "Электроника", priceText: "72 000 ₽", timeAgo: "3 ч назад", imageSystemName: "iphone")
    ]
}

/// A listing category. Backed by Firestore ("categories" collection) and
/// managed by admins from the admin panel — no longer hardcoded.
struct AppCategory: Identifiable, Hashable {
    let id: String
    let title: String

    /// Client-only pseudo-category used as the "show everything" filter
    /// chip on the feed. Never stored in Firestore.
    static let allFilter = AppCategory(id: "__all__", title: "Все")
}
