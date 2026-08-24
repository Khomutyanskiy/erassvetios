//
//  AdminBlogModerationView.swift
//  erassvet
//

import SwiftUI

/// Admin-only screen with the blog moderation on/off toggle plus the queue
/// of posts awaiting approval. Reached from AdminPanelView. Mirrors
/// `AdminModerationView`'s layout for ad moderation.
struct AdminBlogModerationView: View {
    @StateObject private var viewModel = AdminBlogModerationViewModel()
    @State private var isTogglingModeration = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                toggleCard

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
                        Text("Не удалось загрузить посты")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else if viewModel.pendingPosts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Нет постов на модерации")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    HStack {
                        Text("На модерации: \(viewModel.pendingPosts.count)")
                            .font(.footnote.bold())
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }

                    VStack(spacing: 10) {
                        ForEach(viewModel.pendingPosts) { post in
                            PendingPostRow(
                                post: post,
                                isProcessing: viewModel.processingIds.contains(post.id),
                                onApprove: { Task { await viewModel.approve(postId: post.id) } },
                                onReject: { Task { await viewModel.reject(postId: post.id) } }
                            )
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Модерация блога")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { viewModel.isModerationEnabled },
                set: { newValue in
                    isTogglingModeration = true
                    Task {
                        await viewModel.setModerationEnabled(newValue)
                        isTogglingModeration = false
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Модерация постов")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(
                        viewModel.isModerationEnabled
                            ? "Новые посты публикуются только после проверки."
                            : "Новые посты публикуются сразу, без проверки."
                    )
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                }
            }
            .tint(AppTheme.accent)
            .disabled(isTogglingModeration)
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

private struct PendingPostRow: View {
    let post: BlogPost
    let isProcessing: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.authorName)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    if !post.timeAgoText.isEmpty {
                        Text(post.timeAgoText)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()
            }

            if !post.text.isEmpty {
                Text(post.text)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(4)
            }

            HStack(spacing: 10) {
                Button {
                    onReject()
                } label: {
                    Label("Отклонить", systemImage: "xmark")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(Color(hex: "E8352B"))
                        .background(Color(hex: "E8352B").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onApprove()
                } label: {
                    Label("Одобрить", systemImage: "checkmark")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(Color(hex: "3FBF7F"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.5 : 1)
            .overlay {
                if isProcessing {
                    ProgressView().tint(AppTheme.accent)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.2))
                .frame(width: 44, height: 44)

            if let urlString = post.imageURLs.first, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.footnote.bold())
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Text(String(post.authorName.prefix(1)).uppercased())
                    .font(.footnote.bold())
                    .foregroundColor(AppTheme.accent)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminBlogModerationView()
    }
}
