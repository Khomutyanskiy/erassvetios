//
//  Report.swift
//  erassvet
//

import Foundation
import FirebaseFirestore

/// What kind of content a report points at — used by `AdminReportsView` to
/// know which Firestore document to delete when an admin acts on it.
enum ReportContentType: String {
    case ad
    case blogPost = "blog_post"
    case chat
    case profile

    var title: String {
        switch self {
        case .ad: return "Объявление"
        case .blogPost: return "Пост в блоге"
        case .chat: return "Чат"
        case .profile: return "Профиль"
        }
    }
}

enum ReportStatus: String {
    case open
    case resolved
}

/// A user-filed complaint, stored in the "reports" collection. Any signed-in
/// user can create one; only admins can read/update the list (Firestore
/// rules). Surfaced in the admin panel's "Жалобы" queue — see
/// `AdminReportsViewModel` — which is how the app satisfies App Store
/// Guideline 1.2's requirement that the developer act on reports.
struct Report: Identifiable, Hashable {
    static func == (lhs: Report, rhs: Report) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let type: ReportContentType
    /// id of the underlying document to delete if the admin removes the
    /// content (ad id / blog post id / chat id). Empty for profile-only reports.
    let contentId: String
    /// Short human-readable preview of what was reported (ad title, post
    /// text snippet, etc.) shown in the admin list.
    let contentPreview: String
    let reportedUid: String
    let reportedName: String
    let reporterId: String
    let reason: String
    let status: ReportStatus
    let createdAt: Date?

    init?(id: String, data: [String: Any]) {
        guard
            let typeRaw = data["type"] as? String,
            let type = ReportContentType(rawValue: typeRaw),
            let reportedUid = data["reportedUid"] as? String,
            let reporterId = data["reporterId"] as? String
        else { return nil }

        self.id = id
        self.type = type
        self.contentId = data["contentId"] as? String ?? ""
        self.contentPreview = data["contentPreview"] as? String ?? ""
        self.reportedUid = reportedUid
        self.reportedName = data["reportedName"] as? String ?? "Пользователь"
        self.reporterId = reporterId
        self.reason = data["reason"] as? String ?? ""
        self.status = ReportStatus(rawValue: data["status"] as? String ?? "") ?? .open
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }

    var timeAgoText: String {
        guard let createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    static func newData(
        type: ReportContentType,
        contentId: String,
        contentPreview: String,
        reportedUid: String,
        reportedName: String,
        reporterId: String,
        reason: String
    ) -> [String: Any] {
        [
            "type": type.rawValue,
            "contentId": contentId,
            "contentPreview": contentPreview,
            "reportedUid": reportedUid,
            "reportedName": reportedName,
            "reporterId": reporterId,
            "reason": reason,
            "status": ReportStatus.open.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}
