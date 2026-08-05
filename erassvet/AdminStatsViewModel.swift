//
//  AdminStatsViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Loads simple aggregate counts for the admin "Статистика" screen —
/// total registered users and total ads (both counted server-side via
/// Firestore's count() aggregation, so no documents are downloaded).
@MainActor
final class AdminStatsViewModel: ObservableObject {
    @Published var usersCount: Int?
    @Published var adsCount: Int?
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        let db = Firestore.firestore()
        do {
            async let usersSnapshot = db.collection("users").count.getAggregation(source: .server)
            async let adsSnapshot = db.collection("ads").count.getAggregation(source: .server)
            let (users, ads) = try await (usersSnapshot, adsSnapshot)
            usersCount = Int(truncating: users.count)
            adsCount = Int(truncating: ads.count)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
