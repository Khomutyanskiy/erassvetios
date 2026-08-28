//
//  BlogPostDetailView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth

/// Full post + comment thread, reached by tapping the comment icon on a
/// `BlogPostCard`. Registers a unique view for the post on appear (mirrors
/// `AdDetailView`'s ad-view counter) and lets any signed-in user add a
/// comment; comment authors (and admins, per Firestore rules) can delete
/// their own.
struct BlogPostDetailView: View {
    let post: BlogPost
    @ObservedObject var blogViewModel: BlogViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var statsViewModel = BlogLikeViewModel()
    @StateObject private var commentsViewModel = BlogCommentsViewModel()
    @State private var commentText = ""
    @State private var showAuth = false
    @State private var pendingCommentDelete: BlogComment?
    @State private var showReportDialog = false
    @State private var showReportSentAlert = false
    @State private var showBlockConfirm = false
    @State private var showUnblockConfirm = false

    private let reportReasons = ["Спам или реклама", "Мошенничество", "Оскорбления", "Недопустимый контент", "Другое"]
    private var currentUid: String? { authViewModel.user?.uid }
    private var isOwnPost: Bool { post.authorId == currentUid }
    private var isBlocked: Bool { authViewModel.isBlocked(post.authorId) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        postHeader

                        if post.hasImage {
                            imageSlider
                        }

                        if !post.text.isEmpty {
                            Text(post.text)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        statsRow

                        Divider().overlay(AppTheme.cardBorder)

                        commentsSection
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }

                commentInputBar
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Пост")
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
            .sheet(isPresented: $showAuth) {
                AuthView().environmentObject(authViewModel)
            }
            .alert("Удалить комментарий?", isPresented: Binding(
                get: { pendingCommentDelete != nil },
                set: { if !$0 { pendingCommentDelete = nil } }
            )) {
                Button("Отмена", role: .cancel) { pendingCommentDelete = nil }
                Button("Удалить", role: .destructive) {
                    if let comment = pendingCommentDelete {
                        Task { await commentsViewModel.deleteComment(postId: post.id, comment: comment) }
                    }
                    pendingCommentDelete = nil
                }
            }
            .task {
                statsViewModel.startListening(postId: post.id, currentUid: currentUid)
                commentsViewModel.startListening(postId: post.id)
                await blogViewModel.registerUniqueView(postId: post.id)
            }
            .onDisappear {
                statsViewModel.stopListening()
                commentsViewModel.stopListening()
            }
        }
    }

    private var postHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 36, height: 36)

                if let urlString = post.authorPhotoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Text(String(post.authorName.prefix(1)).uppercased())
                                .font(.footnote.bold())
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Text(String(post.authorName.prefix(1)).uppercased())
                        .font(.footnote.bold())
                        .foregroundColor(AppTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(post.authorName)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                if !post.timeAgoText.isEmpty {
                    Text(post.timeAgoText)
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            if !isOwnPost {
                SubscribeButton(authorId: post.authorId, onRequireAuth: { showAuth = true })
            }

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
            }

            if !isOwnPost {
                reportMenu
            }
        }
    }

    /// "..." menu with report/block actions for the post's author — hidden
    /// on your own posts. Mirrors `AdDetailView.reportMenu`.
    private var reportMenu: some View {
        Menu {
            Button {
                if currentUid == nil { showAuth = true } else { showReportDialog = true }
            } label: {
                Label("Пожаловаться на пост", systemImage: "exclamationmark.bubble")
            }

            if isBlocked {
                Button {
                    showUnblockConfirm = true
                } label: {
                    Label("Разблокировать автора", systemImage: "checkmark.circle")
                }
            } else {
                Button(role: .destructive) {
                    if currentUid == nil { showAuth = true } else { showBlockConfirm = true }
                } label: {
                    Label("Заблокировать автора", systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(AppTheme.textSecondary)
        }
        .confirmationDialog("Причина жалобы", isPresented: $showReportDialog, titleVisibility: .visible) {
            ForEach(reportReasons, id: \.self) { reason in
                Button(reason) {
                    Task {
                        await ReportService.fileReport(
                            type: .blogPost,
                            contentId: post.id,
                            contentPreview: post.text,
                            reportedUid: post.authorId,
                            reportedName: post.authorName,
                            reporterId: currentUid ?? "",
                            reason: reason
                        )
                        showReportSentAlert = true
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Жалоба отправлена", isPresented: $showReportSentAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text("Мы передали её администратору.")
        }
        .alert("Заблокировать автора?", isPresented: $showBlockConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Заблокировать", role: .destructive) {
                Task { await authViewModel.blockUser(post.authorId) }
            }
        } message: {
            Text("Его объявления и посты пропадут из вашей ленты.")
        }
        .alert("Разблокировать автора?", isPresented: $showUnblockConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Разблокировать") {
                Task { await authViewModel.unblockUser(post.authorId) }
            }
        }
    }

    private var shareText: String {
        "\(post.authorName) в блоге eRassvet:\n\n\(post.text)"
    }

    private var imageSlider: some View {
        TabView {
            ForEach(post.imageURLs, id: \.self) { urlString in
                CachedAsyncImage(urlString: urlString)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()
            }
        }
        .frame(height: 240)
        .tabViewStyle(.page(indexDisplayMode: post.imageURLs.count > 1 ? .automatic : .never))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            Button {
                guard let currentUid else {
                    showAuth = true
                    return
                }
                Task { await statsViewModel.toggleLike(postId: post.id, currentUid: currentUid) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: statsViewModel.isLiked ? "heart.fill" : "heart")
                        .foregroundColor(statsViewModel.isLiked ? .red : AppTheme.textSecondary)
                    if statsViewModel.likesCount > 0 {
                        Text("\(statsViewModel.likesCount)")
                    }
                }
            }
            .disabled(statsViewModel.isSubmitting)

            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                if statsViewModel.commentsCount > 0 {
                    Text("\(statsViewModel.commentsCount)")
                }
            }
            .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 6) {
                Image(systemName: "eye")
                Text("\(statsViewModel.views)")
            }
            .foregroundColor(AppTheme.textSecondary)

            Spacer()
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var commentsSection: some View {
        Text("Комментарии")
            .font(.subheadline.bold())
            .foregroundColor(AppTheme.textPrimary)

        if commentsViewModel.isLoading {
            ProgressView()
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        } else if commentsViewModel.comments.isEmpty {
            Text("Пока нет комментариев — будьте первым")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(commentsViewModel.comments) { comment in
                    commentRow(comment)
                }
            }
        }
    }

    private func commentRow(_ comment: BlogComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 28, height: 28)
                Text(String(comment.authorName.prefix(1)).uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(.footnote.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    if !comment.timeAgoText.isEmpty {
                        Text(comment.timeAgoText)
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                Text(comment.text)
                    .font(.footnote)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            if comment.authorId == currentUid {
                Button {
                    pendingCommentDelete = comment
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var commentInputBar: some View {
        HStack(spacing: 10) {
            TextField("", text: $commentText, prompt: Text("Комментарий...").foregroundColor(AppTheme.textSecondary), axis: .vertical)
                .lineLimit(1...4)
                .foregroundColor(AppTheme.textPrimary)
                .padding(12)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))

            Button {
                submitComment()
            } label: {
                if commentsViewModel.isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }
            .frame(width: 40, height: 40)
            .background(AppTheme.accent)
            .clipShape(Circle())
            .disabled(commentsViewModel.isSubmitting || commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(AppTheme.background)
    }

    private func submitComment() {
        guard let user = authViewModel.user else {
            showAuth = true
            return
        }
        let text = commentText
        Task {
            let success = await commentsViewModel.addComment(
                postId: post.id,
                authorId: user.uid,
                authorName: user.displayNameOrFallback,
                authorPhotoURL: user.photoURL?.absoluteString,
                text: text
            )
            if success {
                commentText = ""
            }
        }
    }
}

#Preview {
    BlogPostDetailView(
        post: BlogPost(id: "1", data: [
            "authorId": "u1",
            "authorName": "Алексей",
            "text": "Пример поста"
        ])!,
        blogViewModel: BlogViewModel()
    )
    .environmentObject(AuthViewModel())
}
