//
//  ChatsViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    /// Live-fetched public profiles (name/avatar) of chat partners, keyed by
    /// uid — see `fetchPublicProfile`. Takes priority over the denormalized
    /// `sellerName`/`sellerPhotoURL` snapshot stored on the chat doc, since
    /// those only update when the *other* participant happens to write them.
    @Published var publicProfiles: [String: (name: String, photoURL: String?)] = [:]

    private var listener: ListenerRegistration?
    private var currentUid: String?
    private var fetchedPublicProfileUids: Set<String> = []

    /// Total unread messages across all of the current user's chats — used
    /// for the badge on the "Чаты" tab.
    var totalUnreadCount: Int {
        guard let currentUid else { return 0 }
        return chats.reduce(0) { $0 + $1.unreadCount(for: currentUid) }
    }

    func startListening(uid: String) {
        guard currentUid != uid || listener == nil else { return }
        currentUid = uid
        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = Firestore.firestore()
            .collection("chats")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                self.chats = snapshot?.documents.compactMap { Chat(id: $0.documentID, data: $0.data()) } ?? []
                self.errorMessage = nil
                self.isLoading = false
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        currentUid = nil
        chats = []
        isLoading = true
        publicProfiles = [:]
        fetchedPublicProfileUids = []
    }

    /// Finds or creates the chat thread for this (ad, buyer, seller) triple
    /// and returns it. Safe to call repeatedly — re-opening "Написать
    /// продавцу" on the same ad always resumes the same thread.
    func startOrGetChat(
        adId: String,
        adTitle: String,
        adImageURL: String?,
        sellerId: String,
        sellerName: String,
        sellerPhotoURL: String?,
        buyerId: String,
        buyerName: String,
        buyerPhotoURL: String?
    ) async -> Chat? {
        let chatId = Chat.chatId(adId: adId, uidA: sellerId, uidB: buyerId)
        let ref = Firestore.firestore().collection("chats").document(chatId)
        do {
            let existing = try await ref.getDocument()
            if let data = existing.data(), let chat = Chat(id: chatId, data: data) {
                return chat
            }
            let data: [String: Any] = [
                "adId": adId,
                "adTitle": adTitle,
                "adImageURL": adImageURL as Any,
                "sellerId": sellerId,
                "sellerName": sellerName,
                "sellerPhotoURL": sellerPhotoURL as Any,
                "buyerId": buyerId,
                "buyerName": buyerName,
                "buyerPhotoURL": buyerPhotoURL as Any,
                "participants": [sellerId, buyerId],
                "lastMessage": "",
                "lastSenderId": "",
                "lastMessageAt": FieldValue.serverTimestamp(),
                "unread": [sellerId: 0, buyerId: 0],
                "createdAt": FieldValue.serverTimestamp()
            ]
            try await ref.setData(data, merge: true)
            let created = try await ref.getDocument()
            guard let createdData = created.data() else { return nil }
            return Chat(id: chatId, data: createdData)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Sends a text message and bumps the recipient's unread counter.
    func sendMessage(chatId: String, senderId: String, otherUid: String, text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return await writeMessage(chatId: chatId, senderId: senderId, otherUid: otherUid, text: trimmed, imageURL: nil, previewText: trimmed)
    }

    /// Uploads `image` to Storage and sends it as a photo message. The chat
    /// list preview shows "📷 Фото" (same convention as WhatsApp/Telegram)
    /// since there's no text to show.
    @discardableResult
    func sendImageMessage(chatId: String, senderId: String, otherUid: String, image: UIImage) async -> Bool {
        let db = Firestore.firestore()
        let messageRef = db.collection("chats").document(chatId).collection("messages").document()
        do {
            let imageURL = try await StorageService.uploadImage(image, path: "chats/\(chatId)/\(messageRef.documentID).jpg")
            return await writeMessage(chatId: chatId, senderId: senderId, otherUid: otherUid, text: "", imageURL: imageURL, previewText: "📷 Фото", messageRef: messageRef)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func writeMessage(
        chatId: String,
        senderId: String,
        otherUid: String,
        text: String,
        imageURL: String?,
        previewText: String,
        messageRef: DocumentReference? = nil
    ) async -> Bool {
        let db = Firestore.firestore()
        let chatRef = db.collection("chats").document(chatId)
        let ref = messageRef ?? chatRef.collection("messages").document()
        do {
            var data: [String: Any] = [
                "senderId": senderId,
                "text": text,
                "createdAt": FieldValue.serverTimestamp()
            ]
            if let imageURL {
                data["imageURL"] = imageURL
            }
            try await ref.setData(data)
            try await chatRef.updateData([
                "lastMessage": previewText,
                "lastSenderId": senderId,
                "lastMessageAt": FieldValue.serverTimestamp(),
                "unread.\(otherUid)": FieldValue.increment(Int64(1))
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Fetches a chat partner's public profile ("user_public/{uid}" —
    /// readable by any authenticated user) and caches it, so their avatar
    /// shows up immediately instead of waiting for them to open the app and
    /// self-write it onto every shared chat doc.
    func fetchPublicProfile(uid: String) async {
        guard !uid.isEmpty, !fetchedPublicProfileUids.contains(uid) else { return }
        fetchedPublicProfileUids.insert(uid)
        do {
            let doc = try await Firestore.firestore().collection("user_public").document(uid).getDocument()
            guard let data = doc.data() else { return }
            let name = data["displayName"] as? String ?? ""
            let photoURL = data["photoURL"] as? String
            publicProfiles[uid] = (name, photoURL)
        } catch {
            // Best-effort — falls back to the chat's denormalized snapshot.
        }
    }

    /// Keeps the caller's own denormalized name/photo snapshot on a chat doc
    /// up to date. Needed because `sellerName`/`sellerPhotoURL` (and the buyer
    /// equivalents) are captured once when a chat is created — if the user
    /// later uploads or changes their avatar, older chats still point at
    /// stale (or, for chats created before avatars existed, missing) data.
    /// Safe/cheap to call often: it no-ops when everything already matches.
    func syncOwnProfile(chat: Chat, uid: String, displayName: String, photoURL: String?) async {
        var updates: [String: Any] = [:]
        if uid == chat.sellerId {
            if !displayName.isEmpty && displayName != chat.sellerName { updates["sellerName"] = displayName }
            if photoURL != chat.sellerPhotoURL { updates["sellerPhotoURL"] = photoURL as Any }
        } else if uid == chat.buyerId {
            if !displayName.isEmpty && displayName != chat.buyerName { updates["buyerName"] = displayName }
            if photoURL != chat.buyerPhotoURL { updates["buyerPhotoURL"] = photoURL as Any }
        } else {
            return
        }
        guard !updates.isEmpty else { return }
        try? await Firestore.firestore().collection("chats").document(chat.id).updateData(updates)
    }

    /// Resets the current user's unread counter for a chat (call when opening it).
    func markRead(chatId: String, uid: String) async {
        try? await Firestore.firestore()
            .collection("chats")
            .document(chatId)
            .updateData(["unread.\(uid)": 0])
    }

    /// Blocks/unblocks a chat for the given uid. While `blockedBy` is
    /// non-empty the thread is treated as read-only by both sides' clients
    /// (see ChatDetailView) — this is a client-enforced restriction, same
    /// pattern as the ad-limit/auto-archive rules elsewhere in the app, not
    /// a Firestore-rules-level guarantee.
    @discardableResult
    func setBlocked(chatId: String, uid: String, blocked: Bool) async -> Bool {
        do {
            try await Firestore.firestore()
                .collection("chats")
                .document(chatId)
                .updateData([
                    "blockedBy": blocked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid])
                ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Files a report against the other participant of a chat, for admin
    /// review (Firestore "reports" collection — writable by anyone but only
    /// readable by admins, same pattern as other admin-only collections).
    @discardableResult
    func submitReport(chatId: String, reportedUid: String, reporterId: String, reason: String) async -> Bool {
        do {
            try await Firestore.firestore().collection("reports").addDocument(data: [
                "chatId": chatId,
                "reportedUid": reportedUid,
                "reporterId": reporterId,
                "reason": reason,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Deletes a chat thread (its message subcollection is left behind in
    /// Firestore, same as how ad "viewers" subcollections aren't cleaned up
    /// on ad deletion — orphaned subcollections are inaccessible to clients
    /// via security rules and cost nothing until read).
    @discardableResult
    func deleteChat(chatId: String) async -> Bool {
        do {
            try await Firestore.firestore().collection("chats").document(chatId).delete()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
