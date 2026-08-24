//
//  BlogPost.swift
//  erassvet
//

import Foundation
import FirebaseFirestore

enum BlogPostStatus: String {
    /// Live in the public blog feed.
    case active
    /// Awaiting admin review — only visible to its author and admins,
    /// hidden from the public feed. Only assigned when moderation is turned
    /// on in the admin panel ("app_config/blog_moderation.enabled").
    case pending
    /// Rejected by an admin during moderation.
    case rejected

    var title: String {
        switch self {
        case .active: return "Опубликован"
        case .pending: return "На модерации"
        case .rejected: return "Отклонён"
        }
    }
}

/// A user-written blog post ("image + text"), stored in the "blog_posts"
/// collection. Any registered user can write one; whether it needs approval
/// before appearing in the public feed depends on the admin-controlled
/// moderation toggle (see `BlogViewModel.isModerationEnabled`).
struct BlogPost: Identifiable, Hashable {
    static func == (lhs: BlogPost, rhs: BlogPost) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let authorId: String
    let authorName: String
    let authorPhotoURL: String?
    let text: String
    let imageURLs: [String]
    let status: BlogPostStatus
    let createdAt: Date?
    let likesCount: Int
    let commentsCount: Int
    let views: Int

    var hasImage: Bool { !imageURLs.isEmpty }

    var timeAgoText: String {
        guard let createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    init?(id: String, data: [String: Any]) {
        guard
            let authorId = data["authorId"] as? String,
            let text = data["text"] as? String
        else { return nil }

        self.id = id
        self.authorId = authorId
        self.authorName = data["authorName"] as? String ?? "Пользователь"
        self.authorPhotoURL = data["authorPhotoURL"] as? String
        self.text = text
        if let urls = data["imageURLs"] as? [String] {
            self.imageURLs = urls
        } else if let single = data["imageURL"] as? String, !single.isEmpty {
            // Back-compat with posts created before multi-image support.
            self.imageURLs = [single]
        } else {
            self.imageURLs = []
        }
        self.status = BlogPostStatus(rawValue: data["status"] as? String ?? "") ?? .active
        self.likesCount = data["likesCount"] as? Int ?? 0
        self.commentsCount = data["commentsCount"] as? Int ?? 0
        self.views = data["views"] as? Int ?? 0
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }

    static func newPostData(
        authorId: String,
        authorName: String,
        authorPhotoURL: String?,
        text: String,
        imageURLs: [String],
        initialStatus: BlogPostStatus
    ) -> [String: Any] {
        [
            "authorId": authorId,
            "authorName": authorName,
            "authorPhotoURL": authorPhotoURL as Any,
            "text": text,
            "imageURLs": imageURLs,
            "status": initialStatus.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "likesCount": 0,
            "commentsCount": 0,
            "views": 0
        ]
    }
}
