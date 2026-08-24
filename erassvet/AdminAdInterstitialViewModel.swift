//
//  AdminAdInterstitialViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Drives the admin screen for the ad interstitial ("рекламная шторка")
/// shown right after the splash animation on every launch.
///
/// Content lives as multiple entries in the "ad_interstitials" collection
/// (admin can keep several around and switch between them), while
/// "app_config/ad_interstitial" just stores a pointer + on/off switch:
/// `{ activeId, enabled }`. The client (`AdInterstitialView`) reads the
/// pointer, then the pointed-to entry.
@MainActor
final class AdminAdInterstitialViewModel: ObservableObject {
    @Published var interstitials: [AdInterstitial] = []
    @Published var activeId: String?
    @Published var isEnabled: Bool = true
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var errorMessage: String?

    private var itemsListener: ListenerRegistration?
    private var configListener: ListenerRegistration?
    private let configRef = Firestore.firestore().collection("app_config").document("ad_interstitial")
    private let itemsRef = Firestore.firestore().collection("ad_interstitials")

    func startListening() {
        guard itemsListener == nil else { return }
        isLoading = true
        itemsListener = itemsRef
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.interstitials = snapshot?.documents.compactMap { AdInterstitial(id: $0.documentID, data: $0.data()) } ?? []
            }

        configListener = configRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let self else { return }
            let data = snapshot?.data() ?? [:]
            self.activeId = data["activeId"] as? String
            self.isEnabled = data["enabled"] as? Bool ?? true
        }
    }

    func stopListening() {
        itemsListener?.remove()
        itemsListener = nil
        configListener?.remove()
        configListener = nil
    }

    deinit {
        itemsListener?.remove()
        configListener?.remove()
    }

    func setEnabled(_ enabled: Bool) async {
        do {
            try await configRef.setData(["enabled": enabled], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setActive(_ id: String) async {
        do {
            try await configRef.setData(["activeId": id], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func addInterstitial(title: String, subtitle: String, linkURL: String, image: UIImage?) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let id = itemsRef.document().documentID
            var imageURL = ""
            if let image {
                imageURL = try await StorageService.uploadImage(image, path: "ad_interstitials/\(id).jpg")
            }
            try await itemsRef.document(id).setData(AdInterstitial.newData(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                imageURL: imageURL,
                linkURL: linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateInterstitial(id: String, title: String, subtitle: String, linkURL: String, image: UIImage?, existingImageURL: String, removeImage: Bool = false) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            var imageURL = existingImageURL
            if let image {
                imageURL = try await StorageService.uploadImage(image, path: "ad_interstitials/\(id).jpg")
            } else if removeImage {
                if !existingImageURL.isEmpty {
                    await StorageService.deleteImage(url: existingImageURL)
                }
                imageURL = ""
            }
            try await itemsRef.document(id).setData([
                "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
                "subtitle": subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                "imageURL": imageURL,
                "linkURL": linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
            ], merge: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteInterstitial(_ interstitial: AdInterstitial) async {
        do {
            try await itemsRef.document(interstitial.id).delete()
            if !interstitial.imageURL.isEmpty {
                await StorageService.deleteImage(url: interstitial.imageURL)
            }
            if activeId == interstitial.id {
                try await configRef.setData(["activeId": FieldValue.delete()], merge: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
