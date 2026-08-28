//
//  ReportService.swift
//  erassvet
//

import Foundation
import FirebaseFirestore

/// Files a report into the shared "reports" collection — the single queue
/// behind AdminReportsView, no matter whether the flagged content is an ad,
/// a blog post, a chat, or a profile. See `Report` for the schema.
enum ReportService {
    @discardableResult
    static func fileReport(
        type: ReportContentType,
        contentId: String,
        contentPreview: String,
        reportedUid: String,
        reportedName: String,
        reporterId: String,
        reason: String
    ) async -> Bool {
        do {
            try await Firestore.firestore().collection("reports").addDocument(data: Report.newData(
                type: type,
                contentId: contentId,
                contentPreview: contentPreview,
                reportedUid: reportedUid,
                reportedName: reportedName,
                reporterId: reporterId,
                reason: reason
            ))
            return true
        } catch {
            return false
        }
    }
}
