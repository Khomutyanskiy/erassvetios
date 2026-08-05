//
//  FavoritesViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Manages the current user's favorited ads ("users/{uid}/favorites/{adId}").
/// Own ads can be favorited too — no ownership restriction.
@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var favoriteAdIds: Set<String> = []
    @Published var favoriteAds: [Ad] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var idsListener: ListenerRegistration?
    private var currentUid: String?

    func startListening(uid: String) {
        stopListening()
        currentUid = uid
        isLoading = true
        idsListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("favorites")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    return
                }
                let ids = snapshot?.documents.map { $0.documentID } ?? []
                self.favoriteAdIds = Set(ids)
                Task { await self.loadAds(ids: ids) }
            }
    }

    func stopListening() {
        idsListener?.remove()
        idsListener = nil
        currentUid = nil
        favoriteAdIds = []
        favoriteAds = []
    }

    deinit {
        idsListener?.remove()
    }

    func isFavorite(_ adId: String) -> Bool {
        favoriteAdIds.contains(adId)
    }

    /// Adds or removes an ad from favorites. Works for the user's own ads too.
    func toggleFavorite(adId: String, uid: String) async {
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("favorites")
            .document(adId)
        do {
            if favoriteAdIds.contains(adId) {
                try await ref.delete()
            } else {
                try await ref.setData(["createdAt": FieldValue.serverTimestamp()])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches the actual ad documents for the given ids, preserving the
    /// most-recently-favorited-first order.
    private func loadAds(ids: [String]) async {
        guard !ids.isEmpty else {
            favoriteAds = []
            errorMessage = nil
            isLoading = false
            return
        }
        do {
            var fetched: [Ad] = []
            for chunk in ids.chunked(into: 10) {
                let snapshot = try await Firestore.firestore()
                    .collection("ads")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                fetched.append(contentsOf: snapshot.documents.compactMap { Ad(id: $0.documentID, data: $0.data()) })
            }
            let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
            fetched.sort { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
            favoriteAds = fetched
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
