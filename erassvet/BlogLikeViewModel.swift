//
//  BlogLikeViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Drives one blog post's like button, and doubles as the live source for
/// its other lightweight counters (comments, views) since they all live on
/// the same "blog_posts/{postId}" document — one listener covers all three
/// instead of a separate one per counter. Likes: count lives on
/// "blog_posts/{postId}.likesCount"; uniqueness (one like per user, toggle
/// on/off) is enforced the same way as ad views and seller ratings — a
/// marker doc under "blog_posts/{postId}/likers/{uid}", checked/created (or
/// removed) inside a transaction alongside the atomic increment/decrement.
@MainActor
final class BlogLikeViewModel: ObservableObject {
    @Published var likesCount: Int = 0
    @Published var commentsCount: Int = 0
    @Published var views: Int = 0
    @Published var isLiked = false
    @Published var isSubmitting = false

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func startListening(postId: String, currentUid: String?) {
        stopListening()
        listener = db.collection("blog_posts").document(postId)
            .addSnapshotListener { [weak self] snapshot, _ in
                let data = snapshot?.data() ?? [:]
                self?.likesCount = data["likesCount"] as? Int ?? 0
                self?.commentsCount = data["commentsCount"] as? Int ?? 0
                self?.views = data["views"] as? Int ?? 0
            }

        if let currentUid {
            Task { await checkLiked(postId: postId, currentUid: currentUid) }
        } else {
            isLiked = false
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    private func checkLiked(postId: String, currentUid: String) async {
        let doc = try? await db.collection("blog_posts")
            .document(postId)
            .collection("likers")
            .document(currentUid)
            .getDocument()
        isLiked = doc?.exists ?? false
    }

    /// Toggles the current user's like on/off. Optimistic on the local
    /// `isLiked`/`likesCount` (the listener will reconcile if the write
    /// fails), so the heart responds instantly.
    func toggleLike(postId: String, currentUid: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true

        let postRef = db.collection("blog_posts").document(postId)
        let likerRef = postRef.collection("likers").document(currentUid)
        let wasLiked = isLiked

        isLiked = !wasLiked
        likesCount += wasLiked ? -1 : 1

        do {
            _ = try await db.runTransaction { transaction, errorPointer in
                let likerSnapshot: DocumentSnapshot
                do {
                    likerSnapshot = try transaction.getDocument(likerRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                if likerSnapshot.exists {
                    transaction.deleteDocument(likerRef)
                    transaction.setData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: postRef, merge: true)
                } else {
                    transaction.setData(["likedAt": FieldValue.serverTimestamp()], forDocument: likerRef)
                    transaction.setData(["likesCount": FieldValue.increment(Int64(1))], forDocument: postRef, merge: true)
                }
                return nil
            }
        } catch {
            // Roll back the optimistic update on failure.
            isLiked = wasLiked
            likesCount += wasLiked ? 1 : -1
        }

        isSubmitting = false
    }
}
