//
//  AdInterstitialView.swift
//  erassvet
//

import SwiftUI
import UIKit

/// "Рекламная шторка" shown once per app launch, right after the splash
/// animation and before the main content appears — a bottom sheet covering
/// 2/3 of the screen height, dimmed backdrop behind it.
///
/// Content is admin-editable via `AdminAdInterstitialView` and resolved
/// ahead of time by `AdInterstitialContent.load()` (kicked off during the
/// splash screen in `RootView`), so this view just renders already-decoded
/// data — no network fetch or image pop-in happens here. When the admin set
/// a link (site, Telegram channel, Instagram, etc.), a "Перейти" button
/// opens it.
struct AdInterstitialView: View {
    let content: AdInterstitialContent
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                VStack(spacing: 16) {
                    Capsule()
                        .fill(AppTheme.cardBorder)
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)

                    Spacer()

                    if let image = content.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 24)
                    } else if !content.imageURLString.isEmpty {
                        // An image is configured but hasn't finished
                        // downloading yet (it loads in the background so it
                        // never blocks the shutter itself) — a shimmer here
                        // instead of a bare icon makes that state read as
                        // "loading" rather than "no image".
                        ShimmerPlaceholder()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 24)
                    } else {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 34))
                            .foregroundColor(AppTheme.accent)
                    }

                    Text(content.title)
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    ScrollView {
                        Text(content.subtitle)
                            .font(.body)
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    if let url = content.resolvedLinkURL {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Text("Перейти")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: proxy.size.height * 2 / 3)
                .background(AppTheme.card)
                .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
                .overlay(alignment: .top) {
                    RoundedCorner(radius: 24, corners: [.topLeft, .topRight])
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .padding(16)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .transition(.opacity)
    }
}

/// Rounds only the specified corners — used for the interstitial's
/// bottom-sheet panel (top corners only, flush with the screen edge below).
private struct RoundedCorner: Shape {
    var radius: CGFloat = 0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    AdInterstitialView(content: AdInterstitialContent(), onClose: {})
}
