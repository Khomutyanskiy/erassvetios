//
//  AdInterstitial.swift
//  erassvet
//

import Foundation
import FirebaseFirestore

/// One entry in the admin-managed pool of ad shutter content
/// ("ad_interstitials" collection). Exactly one of these can be marked
/// active at a time via "app_config/ad_interstitial.activeId" — see
/// `AdminAdInterstitialViewModel` and `AdInterstitialView`.
struct AdInterstitial: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let imageURL: String
    /// Optional outbound link — a website, Telegram channel, Instagram, etc.
    /// When set, the shutter becomes tappable and opens this URL.
    let linkURL: String
    let createdAt: Date?

    init?(id: String, data: [String: Any]) {
        self.id = id
        self.title = data["title"] as? String ?? ""
        self.subtitle = data["subtitle"] as? String ?? ""
        self.imageURL = data["imageURL"] as? String ?? ""
        self.linkURL = data["linkURL"] as? String ?? ""
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }

    static func newData(title: String, subtitle: String, imageURL: String, linkURL: String) -> [String: Any] {
        [
            "title": title,
            "subtitle": subtitle,
            "imageURL": imageURL,
            "linkURL": linkURL,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}
