//
//  SupportContactsViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class SupportContactsViewModel: ObservableObject {
    @Published var contacts: [SupportContact] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    /// Firestore collection expected shape (collection: "support_contacts"):
    /// { type: "email" | "telegram" | "whatsapp" | "max" | "phone" | "other",
    ///   title: "Email поддержки",
    ///   value: "support@erassvet.ru",
    ///   url: "mailto:support@erassvet.ru"  // optional, derived from type+value if omitted
    ///   order: 0 }
    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        listener = Firestore.firestore()
            .collection("support_contacts")
            .order(by: "order")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.errorMessage = nil
                self.contacts = snapshot?.documents.compactMap {
                    SupportContact(id: $0.documentID, data: $0.data())
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
}
