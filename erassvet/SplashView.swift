//
//  SplashView.swift
//  erassvet
//

import SwiftUI

struct SplashView: View {
    @State private var rassvetOpacity: Double = 0
    @State private var rassvetScale: CGFloat = 0.85
    @State private var glow = false

    /// The scarlet "e" starts above and off-screen (opacity 0) and only
    /// starts hopping into place once "Rassvet" is already visible.
    @State private var eOpacity: Double = 0
    @State private var eOffsetY: CGFloat = -50
    @State private var eScale: CGFloat = 0.6

    private let scarlet = Color(hex: "E8352B")

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            HStack(spacing: 0) {
                Text("e")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(scarlet)
                    .opacity(eOpacity)
                    .scaleEffect(eScale)
                    .offset(y: eOffsetY)

                Text("Rassvet")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accent, Color(hex: "6FA3FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(rassvetOpacity)
                    .scaleEffect(rassvetScale)
            }
            .shadow(color: AppTheme.accent.opacity(glow ? 0.55 : 0.15), radius: glow ? 18 : 6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                rassvetOpacity = 1
                rassvetScale = 1
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.4)) {
                glow = true
            }
            animateEBounce()
        }
    }

    /// Drops the scarlet "e" in after "Rassvet" is already on screen, with a
    /// couple of decreasing bounces before it settles into place.
    private func animateEBounce() {
        eOpacity = 1

        withAnimation(.interpolatingSpring(stiffness: 260, damping: 11).delay(0.5)) {
            eOffsetY = 0
            eScale = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 9)) {
                eOffsetY = -16
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                    eOffsetY = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.interpolatingSpring(stiffness: 320, damping: 11)) {
                        eOffsetY = -6
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(.interpolatingSpring(stiffness: 320, damping: 14)) {
                            eOffsetY = 0
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
