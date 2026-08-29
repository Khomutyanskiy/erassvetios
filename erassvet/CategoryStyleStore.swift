//
//  CategoryStyleStore.swift
//  erassvet
//

import FirebaseFirestore

/// App-wide cache of admin-picked color overrides per category, kept in
/// sync with the "categories" collection independently of any single
/// screen's `CategoriesViewModel`. Cards, detail screens, and admin lists
/// all read the same category string (`ad.category`) but don't each carry
/// a live categories listener, so `AppTheme.colorForCategory` consults this
/// singleton instead to pick up admin overrides.
@MainActor
final class CategoryStyleStore {
    static let shared = CategoryStyleStore()

    private var colorHexByTitle: [String: String] = [:]
    private var listener: ListenerRegistration?

    private init() {
        listener = Firestore.firestore().collection("categories")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let docs = snapshot?.documents else { return }
                var colors: [String: String] = [:]
                for doc in docs {
                    guard let title = doc.data()["title"] as? String else { continue }
                    if let hex = doc.data()["colorHex"] as? String, !hex.isEmpty {
                        colors[title] = hex
                    }
                }
                self.colorHexByTitle = colors
            }
    }

    func colorHex(for category: String) -> String? {
        colorHexByTitle[category]
    }
}
