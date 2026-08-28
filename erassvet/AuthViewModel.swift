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
    /// Uids this user has chosen to block — mirrored live from
    /// "users/{uid}.blockedUsers". Ads/blog posts by a blocked author are
    /// filtered out of the feed/blog immediately on the client (see
    /// FeedView/BlogView), and the block also prevents new chats.
    @Published var blockedUserIds: Set<String> = []

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
            blockedUserIds = []
            return
        }
        userDocListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let data = snapshot?.data() ?? [:]
                self.role = data["role"] as? String ?? "user"
                self.blockedUserIds = Set(data["blockedUsers"] as? [String] ?? [])

                // An admin banning this account (per the "Жалобы" queue)
                // takes effect immediately — this is the client-side half of
                // App Store Guideline 1.2's 24h-response requirement; a
                // banned user simply can't stay signed in.
                if data["isBanned"] as? Bool == true {
                    self.errorMessage = "Ваш аккаунт заблокирован администратором за нарушение правил использования."
                    self.signOut()
                }
            }
    }

    /// Adds/removes `uid` from the current user's block list ("users/{me}.
    /// blockedUsers"). Blocking hides that author's ads/blog posts from the
    /// feed immediately (see FeedView/BlogView) and is separate from a
    /// per-chat block (`Chat.blockedBy`), which only affects one thread.
    @discardableResult
    func blockUser(_ uid: String) async -> Bool {
        guard let me = user?.uid, me != uid else { return false }
        do {
            try await Firestore.firestore().collection("users").document(me)
                .setData(["blockedUsers": FieldValue.arrayUnion([uid])], merge: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func unblockUser(_ uid: String) async -> Bool {
        guard let me = user?.uid else { return false }
        do {
            try await Firestore.firestore().collection("users").document(me)
                .setData(["blockedUsers": FieldValue.arrayRemove([uid])], merge: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func isBlocked(_ uid: String) -> Bool { blockedUserIds.contains(uid) }

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
            "isBanned": false,
            "blockedUsers": [String](),
            "acceptedTermsAt": FieldValue.serverTimestamp(),
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

    /// Permanently deletes the signed-in account: re-authenticates with the
    /// given password (Firebase requires a *recent* sign-in before allowing
    /// `Auth.currentUser.delete()`), best-effort cleans up this user's
    /// Firestore data and Storage files, then deletes the Auth account
    /// itself. Returns false (with `errorMessage` set) on any failure —
    /// most commonly a wrong password.
    func deleteAccount(password: String) async -> Bool {
        guard let currentUser = Auth.auth().currentUser, let email = currentUser.email, !email.isEmpty else {
            errorMessage = "Не удалось определить аккаунт для удаления."
            return false
        }
        isLoading = true
        errorMessage = nil
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await currentUser.reauthenticate(with: credential)

            let uid = currentUser.uid
            let avatarURL = currentUser.photoURL?.absoluteString
            await deleteUserData(uid: uid, avatarURL: avatarURL)

            try await currentUser.delete()
            user = nil
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// Best-effort cleanup of everything this user owns before the Auth
    /// account itself is deleted: their ads (+ photos), favorites, avatar,
    /// public profile mirror, chats they're part of, and their own profile
    /// document. Message subcollections under deleted chats are left behind
    /// — same as the app's existing single-chat delete flow — since they're
    /// unreachable via security rules once the parent chat doc is gone.
    private func deleteUserData(uid: String, avatarURL: String?) async {
        let db = Firestore.firestore()

        if let adsSnapshot = try? await db.collection("ads").whereField("sellerId", isEqualTo: uid).getDocuments() {
            for doc in adsSnapshot.documents {
                let imageURLs = doc.data()["imageURLs"] as? [String] ?? []
                try? await doc.reference.delete()
                for url in imageURLs {
                    await StorageService.deleteImage(url: url)
                }
            }
        }

        if let favoritesSnapshot = try? await db.collection("users").document(uid).collection("favorites").getDocuments() {
            for doc in favoritesSnapshot.documents {
                try? await doc.reference.delete()
            }
        }

        if let chatsSnapshot = try? await db.collection("chats").whereField("participants", arrayContains: uid).getDocuments() {
            for doc in chatsSnapshot.documents {
                try? await doc.reference.delete()
            }
        }

        if let avatarURL {
            await StorageService.deleteImage(url: avatarURL)
        }

        try? await db.collection("user_public").document(uid).delete()
        try? await db.collection("users").document(uid).delete()
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
