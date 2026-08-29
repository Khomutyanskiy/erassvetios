//
//  CategoriesViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Loads and manages ad categories ("categories" collection in Firestore).
/// Categories are shown as filter chips on the feed and as the category
/// picker when creating/editing an ad. Adding/removing categories is
/// restricted to admins by Firestore security rules.
@MainActor
final class CategoriesViewModel: ObservableObject {
    @Published var categories: [AppCategory] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isSaving = false

    private var listener: ListenerRegistration?

    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        listener = Firestore.firestore()
            .collection("categories")
            .order(by: "title")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.categories = snapshot?.documents.compactMap { doc in
                    guard let title = doc.data()["title"] as? String else { return nil }
                    return AppCategory(
                        id: doc.documentID,
                        title: title,
                        colorHex: doc.data()["colorHex"] as? String
                    )
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    /// Adds a new category. Only succeeds for admins (enforced by Firestore rules).
    func addCategory(title: String) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        isSaving = true
        errorMessage = nil
        do {
            try await Firestore.firestore().collection("categories").addDocument(data: [
                "title": trimmed,
                "createdAt": FieldValue.serverTimestamp()
            ])
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Saves the admin-picked color override for a category. Pass `nil` to
    /// clear it back to the automatic default. Also clears any leftover
    /// icon fields from the old icon-picker feature. Only succeeds for
    /// admins (enforced by Firestore rules).
    func updateStyle(id: String, colorHex: String?) async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            let data: [String: Any] = [
                "colorHex": colorHex ?? FieldValue.delete(),
                "iconName": FieldValue.delete(),
                "iconURL": FieldValue.delete()
            ]
            try await Firestore.firestore().collection("categories").document(id).setData(data, merge: true)
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Deletes a category. Only succeeds for admins (enforced by Firestore rules).
    func deleteCategory(id: String) async -> Bool {
        do {
            try await Firestore.firestore().collection("categories").document(id).delete()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
