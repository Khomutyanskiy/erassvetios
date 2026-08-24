//
//  AdInterstitialContent.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
#if canImport(UIKit)
import UIKit
#endif

/// Resolved, ready-to-render content for the ad shutter.
///
/// Loading is split in two so a slow network can never make the shutter
/// "not appear at all":
///  - `loadConfig()` fetches just the text/link (small documents), capped at
///    a short timeout, and is what gates whether/when the shutter shows.
///  - `loadImage(urlString:)` downloads the picture separately, also capped
///    with a timeout, and is applied to the already-visible shutter once
///    (if) it arrives — never blocks the shutter's appearance.
struct AdInterstitialContent {
    var title = "Реклама"
    var subtitle = "Здесь скоро появится рекламный блок"
    var linkURL = ""
    var imageURLString = ""
    var image: UIImage?

    /// The link as something the system can actually open. Admins routinely
    /// type "www.example.com" or "example.com" without a scheme — such a
    /// string still makes a valid `URL`, but `UIApplication.open` silently
    /// refuses it, which looked like the "Перейти" button doing nothing.
    /// Anything already carrying a scheme (https, tg, instagram, mailto…)
    /// is passed through untouched.
    var resolvedLinkURL: URL? {
        let trimmed = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }
        return URL(string: "https://" + trimmed)
    }

    /// Returns nil when the shutter shouldn't be shown at all: the admin
    /// turned it off, nothing is marked active, or the content simply
    /// couldn't be read. Showing nothing is better than showing the generic
    /// "Здесь скоро появится рекламный блок" stub over real configured ads,
    /// which is what a too-eager timeout used to produce on cold start.
    static func loadConfig() async -> AdInterstitialContent? {
        let db = Firestore.firestore()

        let configRef = db.collection("app_config").document("ad_interstitial")
        let configData = await fetchData(configRef)
        guard !configData.isEmpty else { return nil }

        let enabled = configData["enabled"] as? Bool ?? true
        guard enabled else { return nil }

        guard let activeId = configData["activeId"] as? String, !activeId.isEmpty else {
            return nil
        }

        let itemRef = db.collection("ad_interstitials").document(activeId)
        let data = await fetchData(itemRef)
        guard !data.isEmpty else { return nil }

        var content = AdInterstitialContent()
        if let t = data["title"] as? String, !t.isEmpty { content.title = t }
        if let s = data["subtitle"] as? String, !s.isEmpty { content.subtitle = s }
        if let link = data["linkURL"] as? String, !link.isEmpty { content.linkURL = link }
        if let imageURLString = data["imageURL"] as? String, !imageURLString.isEmpty {
            content.imageURLString = imageURLString
        }

        return content
    }

    /// Downloads and decodes the shutter's image, retrying once on a
    /// timeout/failure — the same cold-start network warm-up that made
    /// Firestore's first read slow can delay the very first URLSession
    /// request too. Still bounded: gives up after two attempts and returns
    /// nil (shutter still shows, minus the picture) rather than hanging.
    static func loadImage(urlString: String) async -> UIImage? {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12

        for attempt in 0..<2 {
            let result: UIImage? = await withTaskGroup(of: UIImage?.self) { group in
                group.addTask {
                    guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
                    return UIImage(data: data)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 13_000_000_000)
                    return nil
                }
                let first = (await group.next()) ?? nil
                group.cancelAll()
                return first
            }

            if let result { return result }
            if attempt == 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
        }
        return nil
    }

    /// Fetches a document's data with a generous timeout, retrying once.
    /// The first Firestore read after a cold launch also has to bring up the
    /// connection, which can take several seconds on a slow network — a
    /// short timeout here was cutting real content off and falling back to
    /// the placeholder. The shutter appearing a moment later is fine; it's
    /// decoupled from the splash screen and never blocks it.
    private static func fetchData(_ ref: DocumentReference) async -> [String: Any] {
        for attempt in 0..<2 {
            let result: [String: Any]? = await withTaskGroup(of: [String: Any]?.self) { group in
                group.addTask {
                    (try? await ref.getDocument())?.data()
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    return nil
                }
                let first = (await group.next()) ?? nil
                group.cancelAll()
                return first
            }

            if let result, !result.isEmpty { return result }
            if attempt == 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
        }
        return [:]
    }
}
