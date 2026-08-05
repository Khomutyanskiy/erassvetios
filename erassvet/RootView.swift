//
//  RootView.swift
//  erassvet
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showSplash = true

    var body: some View {
        ZStack {
            MainTabView()
                .environmentObject(authViewModel)

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    RootView().environmentObject(AuthViewModel())
}
