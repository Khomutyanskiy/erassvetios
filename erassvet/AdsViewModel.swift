//
//  AdsViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AdsViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var errorMessage: String?

    /// Counts this seller's currently active-or-pending ads (server-side
    /// count, no documents downloaded) — used to enforce the 10-active-ads
    /// limit before publishing a new one. Pending ads count too, so the
    /// limit can't be gamed by submitting a pile of listings for moderation.
    /// Fails open (returns 0) on a transient error so a network hiccup never
    /// blocks publishing outright.
    func activeAdCount(for sellerId: String) async -> Int {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("ads")
                .whereField("sellerId", isEqualTo: sellerId)
                .whereField("status", in: [AdStatus.active.rawValue, AdStatus.pending.rawValue])
                .count
                .getAggregation(source: .server)
            return Int(truncating: snapshot.count)
        } catch {
            return 0
        }
    }

    /// Reads the admin-controlled moderation toggle ("app_config/moderation.
    /// enabled"). Fails open (returns false, i.e. no moderation) on error so
    /// a network hiccup never blocks publishing outright.
    func isModerationEnabled() async -> Bool {
        do {
            let doc = try await Firestore.firestore()
                .collection("app_config")
                .document("moderation")
                .getDocument()
            return doc.data()?["enabled"] as? Bool ?? false
        } catch {
            return false
        }
    }

    /// Creates a new ad document in Firestore ("ads" collection), uploading
    /// up to 5 photos to Storage first under `ad_images/{sellerId}/{adId}/`.
    func createAd(
        title: String,
        description: String,
        category: String,
        price: Double?,
        street: String,
        house: String,
        apartment: String,
        note: String,
        latitude: Double?,
        longitude: Double?,
        sellerId: String,
        sellerName: String,
        sellerPhotoURL: String?,
        dealType: AdDealType,
        contacts: UserContacts,
        newImages: [UIImage],
        initialStatus: AdStatus = .active
    ) async -> Bool {
        isSaving = true
        errorMessage = nil

        let adRef = Firestore.firestore().collection("ads").document()
        do {
            let imageURLs = try await uploadImages(newImages, sellerId: sellerId, adId: adRef.documentID)
            let data = Ad.newAdData(
                title: title,
                description: description,
                category: category,
                price: price,
                street: street,
                house: house,
                apartment: apartment,
                note: note,
                latitude: latitude,
                longitude: longitude,
                sellerId: sellerId,
                sellerName: sellerName,
                sellerPhotoURL: sellerPhotoURL,
                dealType: dealType,
                contacts: contacts,
                imageURLs: imageURLs,
                initialStatus: initialStatus
            )
            try await adRef.setData(data)
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Updates an existing ad's editable content fields. `keptImageURLs` are
    /// already-uploaded photos the user chose to keep; `newImages` are freshly
    /// picked photos to upload now. Together they must not exceed 5.
    func updateAd(
        id: String,
        title: String,
        description: String,
        category: String,
        price: Double?,
        street: String,
        house: String,
        apartment: String,
        note: String,
        latitude: Double?,
        longitude: Double?,
        dealType: AdDealType,
        contacts: UserContacts,
        sellerId: String,
        keptImageURLs: [String],
        newImages: [UIImage]
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            let uploadedURLs = try await uploadImages(newImages, sellerId: sellerId, adId: id)
            let data = Ad.updateData(
                title: title,
                description: description,
                category: category,
                price: price,
                street: street,
                house: house,
                apartment: apartment,
                note: note,
                latitude: latitude,
                longitude: longitude,
                dealType: dealType,
                contacts: contacts,
                imageURLs: keptImageURLs + uploadedURLs
            )
            try await Firestore.firestore().collection("ads").document(id).updateData(data)
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Uploads each image to `ad_images/{sellerId}/{adId}/{index}.jpg` and
    /// returns their download URLs in order.
    private func uploadImages(_ images: [UIImage], sellerId: String, adId: String) async throws -> [String] {
        guard !images.isEmpty else { return [] }
        var urls: [String] = []
        for (index, image) in images.enumerated() {
            let path = "ad_images/\(sellerId)/\(adId)/\(UUID().uuidString)_\(index).jpg"
            let url = try await StorageService.uploadImage(image, path: path)
            urls.append(url)
        }
        return urls
    }

    /// Sets an ad's active/inactive status ("Снять" / "Опубликовать снова").
    func setStatus(adId: String, status: AdStatus) async -> Bool {
        do {
            try await Firestore.firestore()
                .collection("ads")
                .document(adId)
                .updateData(["status": status.rawValue])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// "Перевыпустить" — reactivates the ad and refreshes its createdAt so
    /// it jumps back to the top of the feed.
    func reissue(adId: String) async -> Bool {
        do {
            try await Firestore.firestore()
                .collection("ads")
                .document(adId)
                .updateData([
                    "status": AdStatus.active.rawValue,
                    "createdAt": FieldValue.serverTimestamp()
                ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Deletes an ad permanently, best-effort cleaning up its photos in Storage.
    func deleteAd(adId: String, imageURLs: [String] = []) async -> Bool {
        do {
            try await Firestore.firestore().collection("ads").document(adId).delete()
            for url in imageURLs {
                await StorageService.deleteImage(url: url)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Registers a unique view for an ad using a per-viewer marker document
    /// in a "viewers" subcollection. If this viewer hasn't been recorded
    /// yet, creates the marker and atomically increments `views` by 1.
    func registerUniqueView(adId: String) async {
        let db = Firestore.firestore()
        let viewerRef = db.collection("ads").document(adId).collection("viewers").document(ViewerIdentity.id)
        let adRef = db.collection("ads").document(adId)

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
                transaction.updateData(["views": FieldValue.increment(Int64(1))], forDocument: adRef)
                return nil
            }
        } catch {
            // Не критично для UX — просто не засчитываем просмотр при ошибке сети.
        }
    }
}
