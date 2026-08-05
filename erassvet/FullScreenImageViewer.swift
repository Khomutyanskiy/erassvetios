//
//  FullScreenImageViewer.swift
//  erassvet
//

import SwiftUI

/// Fullscreen, swipeable, pinch-to-zoom photo viewer — opened by tapping a
/// photo in an ad's image carousel. Starts on whichever photo was visible.
struct FullScreenImageViewer: View {
    let imageURLs: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                    ZoomableAsyncImage(urlString: urlString)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(16)
        }
        .statusBarHidden()
    }
}

private struct ZoomableAsyncImage: View {
    let urlString: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: urlString)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value, 1), 5)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale == 1 {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                        )
                        .simultaneousGesture(
                            scale > 1 ?
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                            : nil
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                } else if phase.error != nil {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }
}

#Preview {
    FullScreenImageViewer(imageURLs: [], selectedIndex: .constant(0))
}
