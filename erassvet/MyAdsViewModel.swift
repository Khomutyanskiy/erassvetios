//
//  MyAdsViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Loads the current user's own ads ("Мои объявления") in real time.
@MainActor
final class MyAdsViewModel: ObservableObject {
    @Published var ads: [Ad] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    /// Active ads older than this (since publish or last "Перевыпустить")
    /// are automatically moved to "Неактивно" so the feed doesn't fill up
    /// with abandoned listings.
    private static let staleAfterDays = 30

    private var listener: ListenerRegistration?
    /// Ad ids we've already fired an auto-archive write for this session,
    /// so a rapid string of snapshot updates doesn't re-send the same update.
    private var archivingInFlight: Set<String> = []

    var activeCount: Int { ads.filter { $0.status == .active }.count }

    func startListening(sellerId: String) {
        stopListening()
        isLoading = true
        listener = Firestore.firestore()
            .collection("ads")
            .whereField("sellerId", isEqualTo: sellerId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                let ads = snapshot?.documents.compactMap { Ad(id: $0.documentID, data: $0.data()) } ?? []
                self.ads = ads
                self.autoArchiveStaleAds(ads)
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        archivingInFlight = []
    }

    /// Best-effort: flips any active ad older than `staleAfterDays` to
    /// "Неактивно". Only the owner's own client can do this (Firestore
    /// rules only allow the seller to update their ad), so this runs
    /// whenever the seller's own "Мои объявления" list loads.
    private func autoArchiveStaleAds(_ ads: [Ad]) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Self.staleAfterDays, to: Date()) else { return }
        for ad in ads where ad.status == .active {
            guard let createdAt = ad.createdAt, createdAt < cutoff else { continue }
            guard !archivingInFlight.contains(ad.id) else { continue }
            archivingInFlight.insert(ad.id)
            Task {
                try? await Firestore.firestore()
                    .collection("ads")
                    .document(ad.id)
                    .updateData(["status": AdStatus.inactive.rawValue])
            }
        }
    }

    deinit {
        listener?.remove()
    }
}
