//
//  MyBlogSubscriptionsView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth

/// One author's section in `MyBlogSubscriptionsView` — their display name
/// (already resolved via `BlogPost.displayAuthorName`, so an admin author
/// still reads as "Администрация сервиса" here too) plus every active post
/// of theirs.
private struct AuthorPostsGroup: Identifiable {
    let authorId: String
    let authorName: String
    let posts: [BlogPost]
    var id: String { authorId }
}

/// Sheet opened from the bell icon on the Блог header — shows every author
/// the current user is subscribed to, each as a named section, with their
/// active blog posts listed underneath using the same `BlogPostCard` as the
/// main blog feed. Reuses `BlogViewModel`'s live "blog_posts" listener and
/// filters client-side, the same pattern `BlogView` already uses for
/// blocked-user filtering.
struct MyBlogSubscriptionsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = BlogViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var pendingDelete: BlogPost?
    @State private var editingPost: BlogPost?
    @State private var openedPost: BlogPost?
    @State private var showAuth = false

    private var groups: [AuthorPostsGroup] {
        let posts = viewModel.posts.filter { authViewModel.subscribedAuthorIds.contains($0.authorId) }
        let byAuthor = Dictionary(grouping: posts, by: \.authorId)
        return byAuthor.map { authorId, posts in
            AuthorPostsGroup(
                authorId: authorId,
                authorName: posts.first?.displayAuthorName ?? "Пользователь",
                posts: posts.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            )
        }
        .sorted { $0.authorName.localizedCaseInsensitiveCompare($1.authorName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && groups.isEmpty {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if authViewModel.subscribedAuthorIds.isEmpty {
                    emptyState(
                        icon: "bell.slash",
                        text: "Вы пока ни на кого не подписаны"
                    )
                } else if groups.isEmpty {
                    emptyState(
                        icon: "tray",
                        text: "У авторов, на которых вы подписаны, пока нет постов"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(groups) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.authorName)
                                        .font(.headline)
                                        .foregroundColor(AppTheme.textPrimary)

                                    VStack(spacing: 14) {
                                        ForEach(group.posts) { post in
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
                        }
                        .padding(16)
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Мои подписки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
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
            }
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(AppTheme.textSecondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MyBlogSubscriptionsView().environmentObject(AuthViewModel())
}
