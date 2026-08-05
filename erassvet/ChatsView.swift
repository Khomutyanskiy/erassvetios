//
//  ChatsView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth

/// Real-time list of the current user's chat threads (with buyers, if they're
/// a seller, and with sellers, if they're a buyer). Tapping a chat opens
/// ChatDetailView.
struct ChatsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var chatsViewModel: ChatsViewModel
    @State private var showAuth = false
    @State private var chatPendingDeletion: Chat?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PageHeader(title: "Чаты")
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationDestination(for: Chat.self) { chat in
                ChatDetailView(chat: chat, isPushedInTabBar: true)
            }
            .sheet(isPresented: $showAuth) {
                AuthView().environmentObject(authViewModel)
            }
            .onAppear {
                syncOwnAvatarAcrossChats()
                fetchOtherParticipantsAvatars()
            }
            .onChange(of: chatsViewModel.chats) { _ in
                syncOwnAvatarAcrossChats()
                fetchOtherParticipantsAvatars()
            }
            .alert(
                "Удалить чат?",
                isPresented: Binding(
                    get: { chatPendingDeletion != nil },
                    set: { if !$0 { chatPendingDeletion = nil } }
                )
            ) {
                Button("Отмена", role: .cancel) {
                    chatPendingDeletion = nil
                }
                Button("Удалить", role: .destructive) {
                    if let chat = chatPendingDeletion {
                        Task { await chatsViewModel.deleteChat(chatId: chat.id) }
                    }
                    chatPendingDeletion = nil
                }
            } message: {
                Text("Переписка будет удалена без возможности восстановления.")
            }
        }
    }

    /// Backfills this device's current name/avatar onto every visible chat,
    /// so threads created before an avatar was uploaded (or with an outdated
    /// one) pick up the current photo without needing a data migration.
    private func syncOwnAvatarAcrossChats() {
        guard let user = authViewModel.user else { return }
        let uid = user.uid
        let displayName = user.displayNameOrFallback
        let photoURL = user.photoURL?.absoluteString
        for chat in chatsViewModel.chats {
            Task { await chatsViewModel.syncOwnProfile(chat: chat, uid: uid, displayName: displayName, photoURL: photoURL) }
        }
    }

    /// Live-fetches each chat partner's public profile so their avatar shows
    /// up right away, instead of only after they open the app themselves.
    private func fetchOtherParticipantsAvatars() {
        guard let uid = authViewModel.user?.uid else { return }
        for chat in chatsViewModel.chats {
            let otherUid = chat.otherParticipantId(currentUid: uid)
            Task { await chatsViewModel.fetchPublicProfile(uid: otherUid) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !authViewModel.isAuthenticated {
            emptyState(
                icon: "message",
                message: "Войдите, чтобы переписываться с продавцами",
                showLoginButton: true
            )
        } else if chatsViewModel.isLoading {
            ProgressView()
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = chatsViewModel.errorMessage {
            emptyState(icon: "exclamationmark.triangle", message: error, showLoginButton: false)
        } else if chatsViewModel.chats.isEmpty {
            emptyState(
                icon: "message",
                message: "Здесь появятся переписки с продавцами и покупателями",
                showLoginButton: false
            )
        } else {
            List {
                ForEach(chatsViewModel.chats) { chat in
                    ChatRow(chat: chat, currentUid: authViewModel.user?.uid ?? "")
                        .background(
                            NavigationLink(value: chat) { EmptyView() }
                                .opacity(0)
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                chatPendingDeletion = chat
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                chatPendingDeletion = chat
                            } label: {
                                Label("Удалить чат", systemImage: "trash")
                            }
                        }
                }

                Color.clear
                    .frame(height: 96)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.top, 10)
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

private struct ChatRow: View {
    @EnvironmentObject private var chatsViewModel: ChatsViewModel

    let chat: Chat
    let currentUid: String

    private var unread: Int { chat.unreadCount(for: currentUid) }
    private var otherUid: String { chat.otherParticipantId(currentUid: currentUid) }

    /// Live-fetched public profile takes priority over the chat's own
    /// denormalized snapshot, which only updates when the other participant
    /// happens to open the app after the fact.
    private var resolvedName: String {
        if let cached = chatsViewModel.publicProfiles[otherUid], !cached.name.isEmpty {
            return cached.name
        }
        return chat.otherParticipantName(currentUid: currentUid)
    }

    private var resolvedPhotoURL: String? {
        if let cached = chatsViewModel.publicProfiles[otherUid] {
            return cached.photoURL
        }
        return chat.otherParticipantPhotoURL(currentUid: currentUid)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 52, height: 52)

                if let urlString = resolvedPhotoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Text(String(resolvedName.prefix(1)).uppercased())
                                .font(.headline.bold())
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                } else {
                    Text(String(resolvedName.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundColor(AppTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(resolvedName)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if !chat.timeAgoText.isEmpty {
                        Text(chat.timeAgoText)
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                if !chat.adTitle.isEmpty {
                    Text(chat.adTitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                        .lineLimit(1)
                }

                Text(chat.lastMessage.isEmpty ? "Нет сообщений" : chat.lastMessage)
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if unread > 0 {
                Text("\(unread)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .frame(minWidth: 20)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

#Preview {
    ChatsView()
        .environmentObject(AuthViewModel())
        .environmentObject(ChatsViewModel())
}
