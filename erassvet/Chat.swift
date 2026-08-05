//
//  Chat.swift
//  erassvet
//

import Foundation
import FirebaseFirestore

/// A conversation between a buyer and a seller about a specific ad.
/// Stored in the "chats" collection, id is deterministic
/// (`{adId}_{sortedUidA}_{sortedUidB}`) so re-opening "Написать продавцу"
/// on the same ad always resumes the same thread instead of creating a new one.
struct Chat: Identifiable, Hashable {
    static func == (lhs: Chat, rhs: Chat) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let adId: String
    let adTitle: String
    let adImageURL: String?
    let sellerId: String
    let sellerName: String
    let sellerPhotoURL: String?
    let buyerId: String
    let buyerName: String
    let buyerPhotoURL: String?
    let participants: [String]
    let lastMessage: String
    let lastSenderId: String
    let lastMessageAt: Date?
    let unread: [String: Int]
    /// Uids of participants who have blocked the conversation. When
    /// non-empty the thread becomes read-only for both sides — see
    /// `ChatsViewModel.setBlocked`.
    let blockedBy: [String]

    init?(id: String, data: [String: Any]) {
        guard
            let adId = data["adId"] as? String,
            let sellerId = data["sellerId"] as? String,
            let buyerId = data["buyerId"] as? String,
            let participants = data["participants"] as? [String]
        else { return nil }

        self.id = id
        self.adId = adId
        self.adTitle = data["adTitle"] as? String ?? ""
        self.adImageURL = data["adImageURL"] as? String
        self.sellerId = sellerId
        self.sellerName = data["sellerName"] as? String ?? "Продавец"
        self.sellerPhotoURL = data["sellerPhotoURL"] as? String
        self.buyerId = buyerId
        self.buyerName = data["buyerName"] as? String ?? "Покупатель"
        self.buyerPhotoURL = data["buyerPhotoURL"] as? String
        self.participants = participants
        self.lastMessage = data["lastMessage"] as? String ?? ""
        self.lastSenderId = data["lastSenderId"] as? String ?? ""
        if let timestamp = data["lastMessageAt"] as? Timestamp {
            self.lastMessageAt = timestamp.dateValue()
        } else {
            self.lastMessageAt = nil
        }
        self.unread = data["unread"] as? [String: Int] ?? [:]
        self.blockedBy = data["blockedBy"] as? [String] ?? []
    }

    var isBlocked: Bool { !blockedBy.isEmpty }

    /// True when the current viewer is the one who blocked this chat (as
    /// opposed to the other participant having blocked it).
    func isBlockedByMe(currentUid: String) -> Bool { blockedBy.contains(currentUid) }

    /// Deterministic id for the (ad, buyer, seller) triple.
    static func chatId(adId: String, uidA: String, uidB: String) -> String {
        let sorted = [uidA, uidB].sorted()
        return "\(adId)_\(sorted[0])_\(sorted[1])"
    }

    func otherParticipantId(currentUid: String) -> String {
        participants.first { $0 != currentUid } ?? (currentUid == sellerId ? buyerId : sellerId)
    }

    func otherParticipantName(currentUid: String) -> String {
        currentUid == sellerId ? buyerName : sellerName
    }

    func otherParticipantPhotoURL(currentUid: String) -> String? {
        currentUid == sellerId ? buyerPhotoURL : sellerPhotoURL
    }

    func unreadCount(for uid: String) -> Int { unread[uid] ?? 0 }

    var timeAgoText: String {
        guard let lastMessageAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastMessageAt, relativeTo: Date())
    }
}

/// A single message within a chat's "messages" subcollection.
struct ChatMessage: Identifiable, Hashable {
    let id: String
    let senderId: String
    let text: String
    let createdAt: Date?

    init?(id: String, data: [String: Any]) {
        guard
            let senderId = data["senderId"] as? String,
            let text = data["text"] as? String
        else { return nil }
        self.id = id
        self.senderId = senderId
        self.text = text
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}
