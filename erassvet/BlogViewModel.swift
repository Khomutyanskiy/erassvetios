//
//  BlogViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// One slot in the post-editing photo row: either one of the post's
/// existing photos (kept as-is unless removed) or a freshly picked one
/// waiting to be uploaded. `CreateBlogPostView` keeps these in display
/// order so per-photo removal and reordering-by-deletion both just work.
enum BlogImageSlot {
    case existing(String)
    case picked(UIImage)
    /// Placeholder shown the instant a photo is picked, before it's
    /// finished decoding — gives each photo its own loading spinner
    /// instead of one shared spinner for the whole batch.
    case loading(UUID)
}

/// Drives the public Блог tab: the live feed of approved posts, plus
/// creating a new post (image optional). Whether a freshly-created post
/// goes straight to `.active` or sits in `.pending` depends on the
/// admin-controlled "app_config/blog_moderation.enabled" toggle — the same
/// pattern `AdsViewModel` uses for ad moderation.
@MainActor
final class BlogViewModel: ObservableObject {
    @Published var posts: [BlogPost] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isSaving = false

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        listener = db.collection("blog_posts")
            .whereField("status", isEqualTo: BlogPostStatus.active.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.posts = snapshot?.documents.compactMap { BlogPost(id: $0.documentID, data: $0.data()) } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    /// Reads the admin-controlled moderation toggle. Fails open (returns
    /// false, i.e. no moderation) on error so a network hiccup never blocks
    /// posting outright.
    func isModerationEnabled() async -> Bool {
        do {
            let doc = try await db.collection("app_config").document("blog_moderation").getDocument()
            return doc.data()?["enabled"] as? Bool ?? false
        } catch {
            return false
        }
    }

    @discardableResult
    func createPost(authorId: String, authorName: String, authorPhotoURL: String?, text: String, images: [UIImage]) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let postRef = db.collection("blog_posts").document()
        do {
            var imageURLs: [String] = []
            for (index, image) in images.prefix(3).enumerated() {
                let url = try await StorageService.uploadImage(image, path: "blog_posts/\(authorId)/\(postRef.documentID)_\(index).jpg")
                imageURLs.append(url)
            }
            let moderationEnabled = await isModerationEnabled()
            let status: BlogPostStatus = moderationEnabled ? .pending : .active
            let data = BlogPost.newPostData(
                authorId: authorId,
                authorName: authorName,
                authorPhotoURL: authorPhotoURL,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                imageURLs: imageURLs,
                initialStatus: status
            )
            try await postRef.setData(data)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Lets the author edit their own post's text and photos. `imageSlots`
    /// is the final, ordered set of photos to keep — existing ones are left
    /// alone, picked ones get uploaded, and any of the post's old photos
    /// that no longer appear in `imageSlots` (removed via the "×" on their
    /// thumbnail) get deleted from Storage. Re-runs the moderation check so
    /// an edited post goes back through review if moderation is on — same
    /// as a freshly created one.
    @discardableResult
    func updateOwnPost(_ post: BlogPost, text: String, imageSlots: [BlogImageSlot]) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let keptURLs = Set(imageSlots.compactMap { slot -> String? in
                if case .existing(let url) = slot { return url }
                return nil
            })
            for oldURL in post.imageURLs where !keptURLs.contains(oldURL) {
                await StorageService.deleteImage(url: oldURL)
            }

            var imageURLs: [String] = []
            let suffix = Int(Date().timeIntervalSince1970)
            for (index, slot) in imageSlots.prefix(3).enumerated() {
                switch slot {
                case .existing(let url):
                    imageURLs.append(url)
                case .picked(let image):
                    let url = try await StorageService.uploadImage(image, path: "blog_posts/\(post.authorId)/\(post.id)_\(index)_\(suffix).jpg")
                    imageURLs.append(url)
                case .loading:
                    // Submit is disabled in the UI while any photo is still
                    // decoding, so this shouldn't normally be reachable —
                    // skip it defensively rather than uploading a blank.
                    continue
                }
            }

            let moderationEnabled = await isModerationEnabled()
            let status: BlogPostStatus = moderationEnabled ? .pending : .active

            try await db.collection("blog_posts").document(post.id).setData([
                "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
                "imageURLs": imageURLs,
                "status": status.rawValue
            ], merge: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Lets the author delete their own post (own-content cleanup —
    /// separate from admin moderation's approve/reject).
    func deleteOwnPost(_ post: BlogPost) async {
        do {
            try await db.collection("blog_posts").document(post.id).delete()
            for imageURL in post.imageURLs {
                await StorageService.deleteImage(url: imageURL)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Registers a unique view for a post the same way `AdsViewModel`
    /// counts unique ad views: a per-viewer marker doc under
    /// "blog_posts/{postId}/viewers", checked/created inside a transaction
    /// alongside an atomic `views` increment. `viewerId` should be the
    /// signed-in uid when available, falling back to the per-device
    /// `ViewerIdentity.id` for guests.
    func registerUniqueView(postId: String, viewerId: String = ViewerIdentity.id) async {
        let viewerRef = db.collection("blog_posts").document(postId).collection("viewers").document(viewerId)
        let postRef = db.collection("blog_posts").document(postId)

        do {
            let existing = try await viewerRef.getDocument()
            if existing.exists { return }

            _ = try await db.runTransaction { transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(viewerRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                if snapshot.exists { return nil }

                transaction.setData(["viewedAt": FieldValue.serverTimestamp()], forDocument: viewerRef)
                transaction.updateData(["views": FieldValue.increment(Int64(1))], forDocument: postRef)
                return nil
            }
        } catch {
            // Non-critical — a failed view count shouldn't surface an error.
        }
    }
}
