//
//  BlogCommentsViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Drives the comment thread under one blog post. Live list from
/// "blog_posts/{postId}/comments" (oldest first), plus keeping the post's
/// denormalized "commentsCount" in step with adds/removes so the feed card
/// can show a count without opening the thread.
@MainActor
final class BlogCommentsViewModel: ObservableObject {
    @Published var comments: [BlogComment] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func startListening(postId: String) {
        guard listener == nil else { return }
        isLoading = true
        listener = db.collection("blog_posts").document(postId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.comments = snapshot?.documents.compactMap { BlogComment(id: $0.documentID, data: $0.data()) } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    @discardableResult
    func addComment(postId: String, authorId: String, authorName: String, authorPhotoURL: String?, text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmitting else { return false }
        if let violation = ContentModerationService.violationMessage(for: trimmed) {
            errorMessage = violation
            return false
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let postRef = db.collection("blog_posts").document(postId)
        let commentRef = postRef.collection("comments").document()

        do {
            try await commentRef.setData(BlogComment.newData(
                authorId: authorId,
                authorName: authorName,
                authorPhotoURL: authorPhotoURL,
                text: trimmed
            ))
            try await postRef.setData(["commentsCount": FieldValue.increment(Int64(1))], merge: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Lets a comment's author (or an admin, per Firestore rules) remove it.
    func deleteComment(postId: String, comment: BlogComment) async {
        let postRef = db.collection("blog_posts").document(postId)
        do {
            try await postRef.collection("comments").document(comment.id).delete()
            try await postRef.setData(["commentsCount": FieldValue.increment(Int64(-1))], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
