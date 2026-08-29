//
//  StorageService.swift
//  erassvet
//

import Foundation
import FirebaseStorage
#if canImport(UIKit)
import UIKit
#endif

enum StorageServiceError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "Не удалось подготовить изображение к загрузке."
        }
    }
}

/// Thin async/await wrapper around Firebase Storage for uploading and
/// deleting images (avatars, ad photos). Uses continuation-based bridging
/// over the completion-handler APIs for maximum SDK-version compatibility.
enum StorageService {
    /// JPEG-compresses `image` and uploads it to `path`, returning the
    /// public download URL string.
    static func uploadImage(_ image: UIImage, path: String, compressionQuality: CGFloat = 0.75) async throws -> String {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw StorageServiceError.imageEncodingFailed
        }
        let ref = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.putData(data, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        let url: URL = try await withCheckedThrowingContinuation { continuation in
            ref.downloadURL { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? StorageServiceError.imageEncodingFailed)
                }
            }
        }
        return url.absoluteString
    }

    /// PNG-encodes `image` and uploads it to `path`, returning the public
    /// download URL string. Used for category icons, where preserving an
    /// alpha channel (so the icon can be tinted via `.renderingMode(.template)`)
    /// matters more than file size — JPEG has no transparency.
    static func uploadPNGImage(_ image: UIImage, path: String) async throws -> String {
        guard let data = image.pngData() else {
            throw StorageServiceError.imageEncodingFailed
        }
        let ref = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.putData(data, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        let url: URL = try await withCheckedThrowingContinuation { continuation in
            ref.downloadURL { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? StorageServiceError.imageEncodingFailed)
                }
            }
        }
        return url.absoluteString
    }

    /// Best-effort delete by download URL — failures are ignored (e.g. the
    /// file was already removed or the URL isn't a Storage URL).
    static func deleteImage(url: String) async {
        guard let ref = try? Storage.storage().reference(forURL: url) else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ref.delete { _ in continuation.resume() }
        }
    }
}
