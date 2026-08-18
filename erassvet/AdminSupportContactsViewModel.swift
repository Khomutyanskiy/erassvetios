//
//  AdminSupportContactsViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Manages the "support_contacts" collection shown on the public Помощь
/// screen (HelpView/SupportContactsViewModel). Create/update/delete are
/// restricted to admins by Firestore security rules.
@MainActor
final class AdminSupportContactsViewModel: ObservableObject {
    @Published var contacts: [SupportContact] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isSaving = false

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        listener = db.collection("support_contacts")
            .order(by: "order")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.contacts = snapshot?.documents.compactMap { SupportContact(id: $0.documentID, data: $0.data()) } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    var nextOrder: Int { (contacts.map(\.order).max() ?? -1) + 1 }

    @discardableResult
    func addContact(type: String, title: String, value: String, url: String) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedValue = value.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, !trimmedValue.isEmpty else { return false }
        isSaving = true
        errorMessage = nil
        var data: [String: Any] = [
            "type": type,
            "title": trimmedTitle,
            "value": trimmedValue,
            "order": nextOrder,
            "createdAt": FieldValue.serverTimestamp()
        ]
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        if !trimmedURL.isEmpty { data["url"] = trimmedURL }
        do {
            try await db.collection("support_contacts").addDocument(data: data)
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    @discardableResult
    func updateContact(id: String, type: String, title: String, value: String, url: String) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedValue = value.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, !trimmedValue.isEmpty else { return false }
        isSaving = true
        errorMessage = nil
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        var data: [String: Any] = ["type": type, "title": trimmedTitle, "value": trimmedValue]
        data["url"] = trimmedURL.isEmpty ? FieldValue.delete() : trimmedURL
        do {
            try await db.collection("support_contacts").document(id).setData(data, merge: true)
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    @discardableResult
    func deleteContact(id: String) async -> Bool {
        do {
            try await db.collection("support_contacts").document(id).delete()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Swaps this contact's `order` with its neighbor in the given direction
    /// (-1 = move up, +1 = move down) so admins can reorder without a
    /// dedicated drag handle.
    @discardableResult
    func move(_ contact: SupportContact, direction: Int) async -> Bool {
        guard let idx = contacts.firstIndex(where: { $0.id == contact.id }) else { return false }
        let newIdx = idx + direction
        guard contacts.indices.contains(newIdx) else { return false }
        let other = contacts[newIdx]
        let batch = db.batch()
        batch.updateData(["order": other.order], forDocument: db.collection("support_contacts").document(contact.id))
        batch.updateData(["order": contact.order], forDocument: db.collection("support_contacts").document(other.id))
        do {
            try await batch.commit()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
