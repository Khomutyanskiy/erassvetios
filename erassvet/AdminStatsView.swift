//
//  AdminStatsView.swift
//  erassvet
//

import SwiftUI

/// Admin-only screen with basic app-wide counters. Reached from AdminPanelView.
struct AdminStatsView: View {
    @StateObject private var statsViewModel = AdminStatsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Общие показатели приложения.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                if statsViewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let error = statsViewModel.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Не удалось загрузить статистику")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 10) {
                        StatCard(
                            icon: "person.2.fill",
                            title: "Зарегистрированные пользователи",
                            value: statsViewModel.usersCount
                        )
                        StatCard(
                            icon: "tag.fill",
                            title: "Объявления",
                            value: statsViewModel.adsCount
                        )
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Статистика")
        .navigationBarTitleDisplayMode(.inline)
        .task { await statsViewModel.load() }
    }
}

private struct StatCard: View {
    let icon: String
    let title: String
    let value: Int?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.16))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                Text(value.map(String.init) ?? "—")
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.textPrimary)
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
        AdminStatsView()
    }
}
