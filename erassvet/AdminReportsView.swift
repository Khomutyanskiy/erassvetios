//
//  AdminReportsView.swift
//  erassvet
//

import SwiftUI

/// Admin-only "Жалобы" queue — every report filed by users (ads, blog posts,
/// chats, profiles), newest first, with quick actions: delete the reported
/// content, ban its author, or dismiss the report. Reached from
/// AdminPanelView.
struct AdminReportsView: View {
    @StateObject private var viewModel = AdminReportsViewModel()
    @State private var pendingDelete: Report?
    @State private var pendingBan: Report?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Реагируйте на жалобы в течение 24 часов: удаляйте нарушающий контент и блокируйте нарушителей.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Не удалось загрузить жалобы")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else if viewModel.reports.isEmpty {
                    Text("Жалоб пока нет")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    if !viewModel.openReports.isEmpty {
                        sectionHeader("Новые (\(viewModel.openReports.count))")
                        VStack(spacing: 10) {
                            ForEach(viewModel.openReports) { report in
                                ReportRow(
                                    report: report,
                                    isBusy: viewModel.isPerformingAction,
                                    onDeleteContent: { pendingDelete = report },
                                    onBanUser: { pendingBan = report },
                                    onDismiss: { Task { await viewModel.markResolved(report) } }
                                )
                            }
                        }
                    }

                    if !viewModel.resolvedReports.isEmpty {
                        sectionHeader("Обработанные (\(viewModel.resolvedReports.count))")
                        VStack(spacing: 10) {
                            ForEach(viewModel.resolvedReports) { report in
                                ReportRow(report: report, isBusy: false, onDeleteContent: nil, onBanUser: nil, onDismiss: nil)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Жалобы")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .alert("Удалить контент?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Отмена", role: .cancel) { pendingDelete = nil }
            Button("Удалить", role: .destructive) {
                if let report = pendingDelete {
                    Task { await viewModel.deleteContent(report) }
                }
                pendingDelete = nil
            }
        } message: {
            Text("Объявление/пост/чат будет удалён без возможности восстановления.")
        }
        .alert("Заблокировать пользователя?", isPresented: Binding(
            get: { pendingBan != nil },
            set: { if !$0 { pendingBan = nil } }
        )) {
            Button("Отмена", role: .cancel) { pendingBan = nil }
            Button("Заблокировать", role: .destructive) {
                if let report = pendingBan {
                    Task { await viewModel.banUser(report) }
                }
                pendingBan = nil
            }
        } message: {
            Text("Аккаунт будет немедленно заблокирован и пользователь выйдет из приложения.")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.bold())
            .foregroundColor(AppTheme.textSecondary)
            .padding(.top, 4)
    }
}

private struct ReportRow: View {
    let report: Report
    let isBusy: Bool
    let onDeleteContent: (() -> Void)?
    let onBanUser: (() -> Void)?
    let onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(report.type.title)
                    .font(.caption2.bold())
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accent.opacity(0.14))
                    .clipShape(Capsule())

                Spacer()

                if !report.timeAgoText.isEmpty {
                    Text(report.timeAgoText)
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Text("Причина: \(report.reason)")
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.textPrimary)

            if !report.contentPreview.isEmpty {
                Text(report.contentPreview)
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Text("Автор: \(report.reportedName)")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

            if onDeleteContent != nil || onBanUser != nil || onDismiss != nil {
                HStack(spacing: 10) {
                    if let onDeleteContent, !report.contentId.isEmpty {
                        actionButton("Удалить контент", icon: "trash", tint: .red, action: onDeleteContent)
                    }
                    if let onBanUser {
                        actionButton("Заблокировать", icon: "hand.raised", tint: .red, action: onBanUser)
                    }
                    if let onDismiss {
                        actionButton("Отклонить", icon: "checkmark", tint: AppTheme.textSecondary, action: onDismiss)
                    }
                }
                .disabled(isBusy)
            }
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .opacity(report.status == .resolved ? 0.6 : 1)
    }

    private func actionButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption.bold())
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}

#Preview {
    NavigationStack {
        AdminReportsView()
    }
}
