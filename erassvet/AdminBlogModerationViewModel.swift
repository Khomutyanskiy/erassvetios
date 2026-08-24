//
//  AdminBlogModerationViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Drives the admin blog moderation screen: the on/off toggle stored at
/// "app_config/blog_moderation.enabled" (read by every client before
/// publishing a post — see `BlogViewModel.isModerationEnabled`), plus the
/// live queue of posts sitting in `.pending` waiting for approval/rejection.
/// Mirrors `AdminModerationViewModel`'s ad-moderation pattern exactly.
@MainActor
final class AdminBlogModerationViewModel: ObservableObject {
    @Published var pendingPosts: [BlogPost] = []
    @Published var isModerationEnabled = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var processingIds: Set<String> = []

    private var postsListener: ListenerRegistration?
    private var configListener: ListenerRegistration?

    func startListening() {
        guard postsListener == nil else { return }
        isLoading = true
        errorMessage = nil

        postsListener = Firestore.firestore()
            .collection("blog_posts")
            .whereField("status", isEqualTo: BlogPostStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.pendingPosts = snapshot?.documents.compactMap { BlogPost(id: $0.documentID, data: $0.data()) } ?? []
            }

        configListener = Firestore.firestore()
            .collection("app_config")
            .document("blog_moderation")
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.isModerationEnabled = snapshot?.data()?["enabled"] as? Bool ?? false
            }
    }

    func stopListening() {
        postsListener?.remove()
        postsListener = nil
        configListener?.remove()
        configListener = nil
    }

    deinit {
        postsListener?.remove()
        configListener?.remove()
    }

    func setModerationEnabled(_ enabled: Bool) async {
        do {
            try await Firestore.firestore()
                .collection("app_config")
                .document("blog_moderation")
                .setData(["enabled": enabled], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approve(postId: String) async {
        processingIds.insert(postId)
        defer { processingIds.remove(postId) }
        do {
            try await Firestore.firestore()
                .collection("blog_posts")
                .document(postId)
                .updateData(["status": BlogPostStatus.active.rawValue])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(postId: String) async {
        processingIds.insert(postId)
        defer { processingIds.remove(postId) }
        do {
            try await Firestore.firestore()
                .collection("blog_posts")
                .document(postId)
                .updateData(["status": BlogPostStatus.rejected.rawValue])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
