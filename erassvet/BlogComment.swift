//
//  BlogComment.swift
//  erassvet
//

import Foundation
import FirebaseFirestore

/// A comment on a blog post, stored in "blog_posts/{postId}/comments".
/// Flat — no replies/threading. The post's "commentsCount" field mirrors
/// this subcollection's size, kept in sync by `BlogCommentsViewModel`.
struct BlogComment: Identifiable, Hashable {
    let id: String
    let authorId: String
    let authorName: String
    let authorPhotoURL: String?
    let text: String
    let createdAt: Date?

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
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }

    static func newData(authorId: String, authorName: String, authorPhotoURL: String?, text: String) -> [String: Any] {
        [
            "authorId": authorId,
            "authorName": authorName,
            "authorPhotoURL": authorPhotoURL as Any,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}
