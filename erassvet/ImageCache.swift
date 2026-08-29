//
//  ImageCache.swift
//  erassvet
//

import UIKit

/// Small in-memory cache for the most recently decoded remote images —
/// used by the blog feed so scrolling a post back into view (or paging
/// through its photo slider) reuses the already-downloaded image instead
/// of re-fetching it. `NSCache` evicts old entries once `countLimit` is
/// exceeded; nothing here is persisted to disk, it only smooths a single
/// session's scrolling.
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Feed shows ~20 ad cards per screenful of scrolling, plus blog
        // photos share this same cache — 10 was evicting feed thumbnails
        // almost immediately, causing repeat downloads/flicker on scroll.
        cache.countLimit = 60
        return cache
    }()

    private init() {}

    func image(for urlString: String) -> UIImage? {
        cache.object(forKey: urlString as NSString)
    }

    func setImage(_ image: UIImage, for urlString: String) {
        cache.setObject(image, forKey: urlString as NSString)
    }
}
