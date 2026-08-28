//
//  AdminReportsViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Drives the admin "Жалобы" queue — a live list of every report filed
/// across ads, blog posts, chats, and profiles (see `Report`), with quick
/// actions to delete the offending content and/or ban its author. This is
/// the admin-facing half of App Store Guideline 1.2: the developer must be
/// able to act on a report (remove content + remove the user) quickly.
@MainActor
final class AdminReportsViewModel: ObservableObject {
    @Published var reports: [Report] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isPerformingAction = false

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    var openReports: [Report] { reports.filter { $0.status == .open } }
    var resolvedReports: [Report] { reports.filter { $0.status == .resolved } }

    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        errorMessage = nil
        listener = db.collection("reports")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                self.reports = snapshot?.documents.compactMap { Report(id: $0.documentID, data: $0.data()) } ?? []
                self.errorMessage = nil
                self.isLoading = false
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func markResolved(_ report: Report) async {
        try? await db.collection("reports").document(report.id).updateData(["status": ReportStatus.resolved.rawValue])
    }

    /// Deletes the reported content itself (ad / blog post / chat). No-op
    /// for profile-only reports, which have nothing to delete.
    func deleteContent(_ report: Report) async {
        guard !report.contentId.isEmpty else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            switch report.type {
            case .ad:
                try await db.collection("ads").document(report.contentId).delete()
            case .blogPost:
                try await db.collection("blog_posts").document(report.contentId).delete()
            case .chat:
                try await db.collection("chats").document(report.contentId).delete()
            case .profile:
                break
            }
            await markResolved(report)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Bans the reported user's account — enforced client-side in real time
    /// by `AuthViewModel.observeUserDocument`, which signs a banned user out
    /// the moment their doc updates.
    func banUser(_ report: Report) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await db.collection("users").document(report.reportedUid).setData(["isBanned": true], merge: true)
            await markResolved(report)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
