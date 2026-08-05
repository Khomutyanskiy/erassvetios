//
//  AdminModerationViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Drives the admin moderation screen: the on/off toggle stored at
/// "app_config/moderation.enabled" (read by every client before publishing —
/// see `AdsViewModel.isModerationEnabled`), plus the live queue of ads
/// sitting in `.pending` waiting for approval/rejection.
@MainActor
final class AdminModerationViewModel: ObservableObject {
    @Published var pendingAds: [Ad] = []
    @Published var isModerationEnabled = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    /// Ids currently being approved/rejected, so their row can show a spinner
    /// and both buttons can be disabled while the write is in flight.
    @Published var processingIds: Set<String> = []

    private var adsListener: ListenerRegistration?
    private var configListener: ListenerRegistration?

    func startListening() {
        guard adsListener == nil else { return }
        isLoading = true
        errorMessage = nil

        adsListener = Firestore.firestore()
            .collection("ads")
            .whereField("status", isEqualTo: AdStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.pendingAds = snapshot?.documents.compactMap { Ad(id: $0.documentID, data: $0.data()) } ?? []
            }

        configListener = Firestore.firestore()
            .collection("app_config")
            .document("moderation")
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.isModerationEnabled = snapshot?.data()?["enabled"] as? Bool ?? false
            }
    }

    func stopListening() {
        adsListener?.remove()
        adsListener = nil
        configListener?.remove()
        configListener = nil
    }

    /// Flips the global moderation switch. When turned off, new ads publish
    /// straight to the feed again; ads already pending stay pending until
    /// approved/rejected here.
    func setModerationEnabled(_ enabled: Bool) async {
        do {
            try await Firestore.firestore()
                .collection("app_config")
                .document("moderation")
                .setData(["enabled": enabled], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approve(adId: String) async {
        processingIds.insert(adId)
        defer { processingIds.remove(adId) }
        do {
            try await Firestore.firestore()
                .collection("ads")
                .document(adId)
                .updateData(["status": AdStatus.active.rawValue])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(adId: String) async {
        processingIds.insert(adId)
        defer { processingIds.remove(adId) }
        do {
            try await Firestore.firestore()
                .collection("ads")
                .document(adId)
                .updateData(["status": AdStatus.rejected.rawValue])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        adsListener?.remove()
        configListener?.remove()
    }
}
