//
//  AdminPanelView.swift
//  erassvet
//

import SwiftUI

/// Admin panel. Only reachable from Profile when the user's Firestore
/// role is "admin". Hosts navigation to individual admin sections.
struct AdminPanelView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.16))
                                .frame(width: 64, height: 64)
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 26))
                                .foregroundColor(AppTheme.accent)
                        }

                        Text("Управление разделами приложения")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    Text("Разделы")
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.textPrimary)

                    VStack(spacing: 0) {
                        NavigationLink {
                            AdminReportsView()
                        } label: {
                            AdminMenuRow(icon: "exclamationmark.bubble", title: "Жалобы")
                        }

                        Divider().overlay(AppTheme.cardBorder)

                        NavigationLink {
                            AdminCategoriesView()
                        } label: {
                            AdminMenuRow(icon: "tag", title: "Категории объявлений")
                        }

                        Divider().overlay(AppTheme.cardBorder)

                        NavigationLink {
                            AdminModerationView()
                        } label: {
                            AdminMenuRow(icon: "checkmark.shield", title: "Модерация объявлений")
                        }

                        Divider().overlay(AppTheme.cardBorder)

                        NavigationLink {
                            AdminUsersView()
                        } label: {
                            AdminMenuRow(icon: "person.2", title: "Пользователи")
                        }

                        Divider().overlay(AppTheme.cardBorder)

                        NavigationLink {
                            AdminSupportContactsView()
                        } label: {
                            AdminMenuRow(icon: "questionmark.circle", title: "Контакты поддержки")
                        }

                        Divider().overlay(AppTheme.cardBorder)

                        NavigationLink {
                            AdminAdInterstitialView()
                        } label: {
                            AdminMenuRow(icon: "megaphone", title: "Рекламная шторка")
                        }

                        Divider().overlay(AppTheme.cardBorder)

                        NavigationLink {
                            AdminBlogModerationView()
                        } label: {
                            AdminMenuRow(icon: "text.bubble", title: "Модерация блога")
                        }

                        Divider().overlay(AppTheme.cardBorder)

                        NavigationLink {
                            AdminStatsView()
                        } label: {
                            AdminMenuRow(icon: "chart.bar", title: "Статистика")
                        }
                    }
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Админ-панель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct AdminMenuRow: View {
    let icon: String
    let title: String
    var isComingSoon: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isComingSoon ? AppTheme.textSecondary : AppTheme.accent)
                .frame(width: 24)
            Text(title)
                .foregroundColor(isComingSoon ? AppTheme.textSecondary : AppTheme.textPrimary)
            Spacer()
            if isComingSoon {
                Text("скоро")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

#Preview {
    AdminPanelView()
}
