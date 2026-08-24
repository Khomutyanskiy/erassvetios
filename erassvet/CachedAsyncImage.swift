//
//  CachedAsyncImage.swift
//  erassvet
//

import SwiftUI

/// Remote image view for the blog feed: only starts downloading once it
/// actually appears (`.task` fires on appear, so images off-screen in the
/// slider don't load ahead of time), serves already-decoded images straight
/// from `ImageCache` on repeat appearances, and shows an animated shimmer
/// instead of a blank/flickering rectangle while a fresh image is loading.
struct CachedAsyncImage: View {
    let urlString: String
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ShimmerPlaceholder()
            }
        }
        .task(id: urlString) {
            await load()
        }
    }

    private func load() async {
        if let cached = ImageCache.shared.image(for: urlString) {
            image = cached
            return
        }
        image = nil
        guard let url = URL(string: urlString) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        guard let decoded = UIImage(data: data) else { return }
        ImageCache.shared.setImage(decoded, for: urlString)
        if !Task.isCancelled {
            image = decoded
        }
    }
}

/// Animated "wave" placeholder shown while a remote image is loading.
/// Not private — also used by `AdInterstitialView` while the shutter's own
/// image is still being fetched in the background.
struct ShimmerPlaceholder: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        Rectangle()
            .fill(AppTheme.card)
            .overlay(
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.14), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: phase * proxy.size.width * 1.6)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
