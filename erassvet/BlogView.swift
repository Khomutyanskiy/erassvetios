//
//  BlogView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth

/// Public Блог tab — every registered user can write a post (image + text).
/// New posts either publish immediately or sit in `.pending` until an admin
/// approves them, depending on the moderation toggle managed from
/// `AdminBlogModerationView`.
struct BlogView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = BlogViewModel()
    @State private var showCreatePost = false
    @State private var showAuth = false
    @State private var pendingDelete: BlogPost?
    @State private var editingPost: BlogPost?
    @State private var openedPost: BlogPost?
    @State private var showSubscriptions = false

    /// Posts by an author the current user has blocked disappear from the
    /// feed immediately (client-side filter — see `AuthViewModel.blockUser`).
    private var visiblePosts: [BlogPost] {
        viewModel.posts.filter { !authViewModel.blockedUserIds.contains($0.authorId) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(
                        title: "Блог",
                        trailingIcon: "square.and.pencil",
                        trailingAction: { startCreatingPost() },
                        secondaryTrailingIcon: "bell",
                        secondaryTrailingAction: {
                            if authViewModel.user == nil {
                                showAuth = true
                            } else {
                                showSubscriptions = true
                            }
                        }
                    )
                    .padding(.top, 8)

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Не удалось загрузить блог")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else if visiblePosts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Пока нет постов — станьте первым")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(visiblePosts) { post in
                                BlogPostCard(
                                    post: post,
                                    isOwnPost: post.authorId == authViewModel.user?.uid,
                                    currentUid: authViewModel.user?.uid,
                                    onEdit: { editingPost = post },
                                    onDelete: { pendingDelete = post },
                                    onRequireAuth: { showAuth = true },
                                    onOpen: { openedPost = post }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreatePost) {
                CreateBlogPostView(viewModel: viewModel)
                    .environmentObject(authViewModel)
            }
            .sheet(item: $editingPost) { post in
                CreateBlogPostView(viewModel: viewModel, existing: post)
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showAuth) {
                AuthView().environmentObject(authViewModel)
            }
            .sheet(item: $openedPost) { post in
                BlogPostDetailView(post: post, blogViewModel: viewModel)
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showSubscriptions) {
                MyBlogSubscriptionsView()
                    .environmentObject(authViewModel)
            }
            .alert("Удалить пост?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Отмена", role: .cancel) { pendingDelete = nil }
                Button("Удалить", role: .destructive) {
                    if let post = pendingDelete {
                        Task { await viewModel.deleteOwnPost(post) }
                    }
                    pendingDelete = nil
                }
            } message: {
                Text("Пост пропадёт из блога.")
            }
            .onAppear { viewModel.startListening() }
            .onDisappear { viewModel.stopListening() }
        }
    }

    private func startCreatingPost() {
        if authViewModel.isAuthenticated {
            showCreatePost = true
        } else {
            showAuth = true
        }
    }
}

/// Not private — also reused by `MyBlogSubscriptionsView` to render posts
/// from subscribed authors with identical styling/behavior.
struct BlogPostCard: View {
    let post: BlogPost
    let isOwnPost: Bool
    let currentUid: String?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRequireAuth: () -> Void
    let onOpen: () -> Void

    @StateObject private var likeViewModel = BlogLikeViewModel()

    private var shareText: String {
        "\(post.displayAuthorName) в блоге eRassvet:\n\n\(post.text)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                                Text(String(post.displayAuthorName.prefix(1)).uppercased())
                                    .font(.footnote.bold())
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Text(String(post.displayAuthorName.prefix(1)).uppercased())
                            .font(.footnote.bold())
                            .foregroundColor(AppTheme.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.displayAuthorName)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    if !post.timeAgoText.isEmpty {
                        Text(post.timeAgoText)
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 14) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    if isOwnPost {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.footnote)
                                .foregroundColor(AppTheme.accent)
                        }
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            if post.hasImage {
                imageSlider
            }

            if !post.text.isEmpty {
                Text(post.text)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
            }

            statsRow
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .onAppear { likeViewModel.startListening(postId: post.id, currentUid: currentUid) }
        .onDisappear { likeViewModel.stopListening() }
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            likeButton

            Button(action: onOpen) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                    if likeViewModel.commentsCount > 0 {
                        Text("\(likeViewModel.commentsCount)")
                    }
                }
            }
            .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 6) {
                Image(systemName: "eye")
                Text("\(likeViewModel.views)")
            }
            .foregroundColor(AppTheme.textSecondary)

            Spacer()

            if !isOwnPost {
                SubscribeButton(authorId: post.authorId, onRequireAuth: onRequireAuth)
            }
        }
        .font(.subheadline)
    }

    private var likeButton: some View {
        Button {
            guard let currentUid else {
                onRequireAuth()
                return
            }
            Task { await likeViewModel.toggleLike(postId: post.id, currentUid: currentUid) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: likeViewModel.isLiked ? "heart.fill" : "heart")
                    .foregroundColor(likeViewModel.isLiked ? .red : AppTheme.textSecondary)
                if likeViewModel.likesCount > 0 {
                    Text("\(likeViewModel.likesCount)")
                        .foregroundColor(likeViewModel.isLiked ? .red : AppTheme.textSecondary)
                }
            }
        }
        .disabled(likeViewModel.isSubmitting)
    }

    private var imageSlider: some View {
        TabView {
            ForEach(post.imageURLs, id: \.self) { urlString in
                CachedAsyncImage(urlString: urlString)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
            }
        }
        .frame(height: 220)
        .tabViewStyle(.page(indexDisplayMode: post.imageURLs.count > 1 ? .automatic : .never))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    BlogView().environmentObject(AuthViewModel())
}
