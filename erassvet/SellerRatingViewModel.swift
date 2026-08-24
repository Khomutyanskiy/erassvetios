//
//  SellerRatingViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Drives a seller's rating — a "+1 / -1" counter stored on
/// "user_public/{sellerId}.rating" (the same publicly-readable mirror doc
/// used for name/avatar, since "users/{uid}" itself is locked to owner-or-
/// admin and buyers rating a seller are neither). `rating` can go negative —
/// down-votes pull it below zero just like up-votes push it above.
///
/// Uniqueness (one vote per voter per seller, either up or down — a voter
/// can't switch or vote twice) is enforced the same way as unique ad views:
/// a marker document under "user_public/{sellerId}/raters/{voterId}"
/// (storing which way they voted), checked/created inside a transaction
/// alongside the atomic increment/decrement.
@MainActor
final class SellerRatingViewModel: ObservableObject {
    @Published var rating: Int = 0
    /// nil = hasn't voted yet, 1 = voted up, -1 = voted down.
    @Published var myVote: Int?
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    var hasVoted: Bool { myVote != nil }

    /// `currentUid` is optional so this can also be used to just display a
    /// seller's rating (e.g. on their own profile) without checking vote
    /// status.
    func startListening(sellerId: String, currentUid: String?) {
        stopListening()
        listener = db.collection("user_public").document(sellerId)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.rating = snapshot?.data()?["rating"] as? Int ?? 0
            }

        if let currentUid, currentUid != sellerId {
            Task { await checkVote(sellerId: sellerId, currentUid: currentUid) }
        } else {
            myVote = nil
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    private func checkVote(sellerId: String, currentUid: String) async {
        let doc = try? await db.collection("user_public")
            .document(sellerId)
            .collection("raters")
            .document(currentUid)
            .getDocument()
        myVote = doc?.data()?["value"] as? Int
    }

    /// Applies `value` (+1 or -1) to `sellerId`'s rating on behalf of
    /// `currentUid`, guarded against double-voting and self-voting.
    func rate(sellerId: String, currentUid: String, value: Int) async {
        guard !hasVoted, !isSubmitting, sellerId != currentUid, value == 1 || value == -1 else { return }
        isSubmitting = true
        errorMessage = nil

        let sellerRef = db.collection("user_public").document(sellerId)
        let raterRef = sellerRef.collection("raters").document(currentUid)

        do {
            _ = try await db.runTransaction { transaction, errorPointer in
                let raterSnapshot: DocumentSnapshot
                do {
                    raterSnapshot = try transaction.getDocument(raterRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                if raterSnapshot.exists { return nil }

                transaction.setData(["value": value, "ratedAt": FieldValue.serverTimestamp()], forDocument: raterRef)
                transaction.setData(["rating": FieldValue.increment(Int64(value))], forDocument: sellerRef, merge: true)
                return nil
            }
            myVote = value
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
