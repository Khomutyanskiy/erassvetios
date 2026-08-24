//
//  FavoritesView.swift
//  erassvet
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var favoritesViewModel: FavoritesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PageHeader(
                    title: "Избранное",
                    trailingIcon: "xmark",
                    trailingAction: { dismiss() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationDestination(for: Ad.self) { ad in
                AdDetailView(ad: ad)
            }
            .sheet(isPresented: $showAuth) {
                AuthView().environmentObject(authViewModel)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !authViewModel.isAuthenticated {
            emptyState(
                icon: "heart",
                message: "Войдите, чтобы сохранять понравившиеся объявления",
                showLoginButton: true
            )
        } else if favoritesViewModel.isLoading {
            ProgressView()
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = favoritesViewModel.errorMessage {
            emptyState(icon: "exclamationmark.triangle", message: error, showLoginButton: false)
        } else if favoritesViewModel.favoriteAds.isEmpty {
            emptyState(icon: "heart", message: "Вы пока ничего не добавили в избранное", showLoginButton: false)
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(favoritesViewModel.favoriteAds) { ad in
                        AdCardRow(ad: ad)
                    }
                }
                .padding(16)
                .padding(.bottom, 110)
            }
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, message: String, showLoginButton: Bool) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(AppTheme.textSecondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if showLoginButton {
                Button {
                    showAuth = true
                } label: {
                    Text("Войти")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    FavoritesView()
        .environmentObject(AuthViewModel())
        .environmentObject(FavoritesViewModel())
}
