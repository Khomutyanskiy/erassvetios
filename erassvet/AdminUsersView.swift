//
//  AdminUsersView.swift
//  erassvet
//

import SwiftUI

/// Admin-only screen listing all registered users ("users" collection in
/// Firestore). Reached from AdminPanelView.
struct AdminUsersView: View {
    @StateObject private var usersViewModel = AdminUsersViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Все аккаунты, зарегистрированные в приложении.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                if usersViewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let error = usersViewModel.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Не удалось загрузить пользователей")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else if usersViewModel.users.isEmpty {
                    Text("Пользователей пока нет")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    HStack {
                        Text("Всего: \(usersViewModel.users.count)")
                            .font(.footnote.bold())
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }

                    VStack(spacing: 10) {
                        ForEach(usersViewModel.users) { user in
                            UserRow(user: user)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Пользователи")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { usersViewModel.startListening() }
        .onDisappear { usersViewModel.stopListening() }
    }
}

private struct UserRow: View {
    let user: AppUser

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)

                if let urlString = user.photoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Text(user.initials)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
                } else {
                    Text(user.initials)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.displayNameOrFallback)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    if user.isAdmin {
                        Text("admin")
                            .font(.caption2.bold())
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.16))
                            .clipShape(Capsule())
                    }
                }

                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                if !user.joinedDateText.isEmpty {
                    Text("Регистрация: \(user.joinedDateText)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        AdminUsersView()
    }
}
