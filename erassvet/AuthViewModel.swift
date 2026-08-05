//
//  AuthViewModel.swift
//  erassvet
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User? {
        didSet {
            observeUserDocument()
            if let user {
                Task { await syncPublicProfile(uid: user.uid, displayName: user.displayNameOrFallback, photoURL: user.photoURL?.absoluteString) }
                PushNotificationManager.shared.requestAuthorization()
                PushNotificationManager.shared.syncToken(uid: user.uid)
            } else if let oldValue {
                // Signing out (or switching accounts on the same device) —
                // stop this device from receiving pushes meant for the
                // account that just signed out.
                PushNotificationManager.shared.clearToken(uid: oldValue.uid)
            }
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// User role, mirrored in real time from Firestore ("users/{uid}.role").
    /// Defaults to "user"; set to "admin" manually in Firestore to unlock the admin panel.
    @Published var role: String = "user"

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var userDocListener: ListenerRegistration?

    var isAuthenticated: Bool { user != nil }
    var isAdmin: Bool { role == "admin" }

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
        userDocListener?.remove()
    }

    /// Keeps `role` in sync with the user's Firestore document, so changing
    /// it manually in the console (e.g. to "admin") updates the app live.
    private func observeUserDocument() {
        userDocListener?.remove()
        userDocListener = nil
        guard let uid = user?.uid else {
            role = "user"
            return
        }
        userDocListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.role = (snapshot?.data()?["role"] as? String) ?? "user"
            }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            user = result.user
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            user = result.user
            await createUserDocument(for: result.user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Creates the corresponding profile document in Firestore ("users/{uid}")
    /// right after a new account is registered.
    private func createUserDocument(for user: User) async {
        let data: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "role": "user",
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .setData(data, merge: true)
        } catch {
            // Не блокируем регистрацию, если запись профиля не удалась —
            // просто логируем и показываем предупреждение.
            errorMessage = "Аккаунт создан, но профиль не сохранён: \(error.localizedDescription)"
        }
    }

    /// Mirrors just the name/avatar into "user_public/{uid}" — a small,
    /// non-sensitive doc any authenticated user is allowed to read (unlike
    /// "users/{uid}", which holds contacts/email and is locked to the owner
    /// or an admin). This is what lets chat partners see each other's real
    /// avatar without either side needing elevated permissions.
    private func syncPublicProfile(uid: String, displayName: String, photoURL: String?) async {
        try? await Firestore.firestore()
            .collection("user_public")
            .document(uid)
            .setData(["displayName": displayName, "photoURL": photoURL as Any], merge: true)
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateDisplayName(_ name: String) async -> Bool {
        guard let currentUser = Auth.auth().currentUser else { return false }
        isLoading = true
        errorMessage = nil
        do {
            let changeRequest = currentUser.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            user = Auth.auth().currentUser
            try? await Firestore.firestore()
                .collection("users")
                .document(currentUser.uid)
                .setData(["displayName": name], merge: true)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// Uploads a new avatar image to Firebase Storage and updates both the
    /// Firebase Auth profile (`photoURL`) and the Firestore user document,
    /// so it's reflected everywhere the user's photo is shown.
    func uploadAvatar(_ image: UIImage) async -> Bool {
        guard let currentUser = Auth.auth().currentUser else { return false }
        isLoading = true
        errorMessage = nil
        do {
            let urlString = try await StorageService.uploadImage(
                image,
                path: "avatars/\(currentUser.uid)/avatar.jpg"
            )
            let changeRequest = currentUser.createProfileChangeRequest()
            changeRequest.photoURL = URL(string: urlString)
            try await changeRequest.commitChanges()
            user = Auth.auth().currentUser
            try? await Firestore.firestore()
                .collection("users")
                .document(currentUser.uid)
                .setData(["photoURL": urlString], merge: true)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func loadContacts() async -> UserContacts {
        guard let currentUser = Auth.auth().currentUser else { return UserContacts() }
        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(currentUser.uid)
                .getDocument()
            let data = doc.data()?["contacts"] as? [String: Any]
            return UserContacts.from(data, fallbackEmail: currentUser.email ?? "")
        } catch {
            errorMessage = error.localizedDescription
            return UserContacts(email: currentUser.email ?? "")
        }
    }

    func saveContacts(_ contacts: UserContacts) async -> Bool {
        guard let currentUser = Auth.auth().currentUser else { return false }
        isLoading = true
        errorMessage = nil
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(currentUser.uid)
                .setData(["contacts": contacts.toDictionary()], merge: true)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
