//
//  RootView.swift
//  erassvet
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showSplash = true
    @State private var showAdInterstitial = false
    @State private var interstitialContent: AdInterstitialContent?

    var body: some View {
        ZStack {
            MainTabView()
                .environmentObject(authViewModel)

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }

            if showAdInterstitial, let interstitialContent {
                AdInterstitialView(content: interstitialContent) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAdInterstitial = false
                    }
                }
            }
        }
        .task {
            // Fetch the shutter's text/link config in parallel with the
            // splash animation (capped by a timeout so a slow network can
            // never make the shutter simply not appear). The image is
            // fetched separately afterwards and never blocks showing the
            // shutter itself.
            async let loadedConfig = AdInterstitialContent.loadConfig()

            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeInOut(duration: 0.4)) {
                showSplash = false
            }

            guard let content = await loadedConfig else { return }
            interstitialContent = content
            withAnimation(.easeInOut(duration: 0.3)) {
                showAdInterstitial = true
            }

            if !content.imageURLString.isEmpty {
                if let image = await AdInterstitialContent.loadImage(urlString: content.imageURLString) {
                    var updated = content
                    updated.image = image
                    interstitialContent = updated
                }
            }
        }
    }
}

#Preview {
    RootView().environmentObject(AuthViewModel())
}
