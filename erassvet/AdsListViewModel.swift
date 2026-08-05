//
//  AdsListViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class AdsListViewModel: ObservableObject {
    @Published var ads: [Ad] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    /// Loads active ads from Firestore ("ads" collection), newest first.
    /// Ads the owner has set to "Неактивно" are hidden from the public feed.
    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        listener = Firestore.firestore()
            .collection("ads")
            .whereField("status", isEqualTo: AdStatus.active.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.ads = snapshot?.documents.compactMap {
                    Ad(id: $0.documentID, data: $0.data())
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }
}
