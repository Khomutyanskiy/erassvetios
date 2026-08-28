//
//  AuthorSubscriptionViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Live subscriber count for one author, read from
/// "user_public/{authorId}.subscribersCount". Whether *I'm* subscribed lives
/// on `AuthViewModel.subscribedAuthorIds` instead (mirrored from my own user
/// doc) — this view model only needs to show the public count, so a single
/// lightweight listener per visible author card is enough.
@MainActor
final class AuthorSubscriptionViewModel: ObservableObject {
    @Published var subscribersCount: Int = 0

    private var listener: ListenerRegistration?

    func startListening(authorId: String) {
        stopListening()
        listener = Firestore.firestore().collection("user_public").document(authorId)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.subscribersCount = snapshot?.data()?["subscribersCount"] as? Int ?? 0
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
