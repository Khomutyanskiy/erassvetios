//
//  AdminUsersViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Real-time list of all registered users ("users" collection), for the
/// admin panel. Reads are only permitted for admins — enforced by Firestore
/// security rules — so this listener will surface a permission error for
/// non-admins rather than being called for them (AdminPanelView is itself
/// only reachable by admins).
@MainActor
final class AdminUsersViewModel: ObservableObject {
    @Published var users: [AppUser] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        errorMessage = nil
        listener = Firestore.firestore()
            .collection("users")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                self.users = snapshot?.documents.map { AppUser(id: $0.documentID, data: $0.data()) } ?? []
                self.errorMessage = nil
                self.isLoading = false
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// Bans/unbans a user directly from the users list. Banning is enforced
    /// client-side in real time — see `AuthViewModel.observeUserDocument`.
    func setBanned(_ user: AppUser, banned: Bool) async {
        try? await Firestore.firestore().collection("users").document(user.id)
            .setData(["isBanned": banned], merge: true)
    }
}
