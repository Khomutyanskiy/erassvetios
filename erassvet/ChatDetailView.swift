//
//  ChatDetailView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth
import PhotosUI

/// A single chat thread — live message list plus an input bar. Marks the
/// thread as read for the current user on appear.
struct ChatDetailView: View {
    let chat: Chat
    /// True when pushed inside a tab's own NavigationStack (e.g. from the
    /// Чаты list) — in that case MainTabView's custom bottom tab bar is
    /// hidden for the duration so the chat occupies the full screen.
    /// Sheet-presented instances (e.g. from AdDetailView) already cover the
    /// tab bar entirely and don't need this.
    var isPushedInTabBar: Bool = false

    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var chatsViewModel: ChatsViewModel
    @StateObject private var messagesViewModel = ChatMessagesViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isTabBarHidden) private var isTabBarHidden

    @State private var draft = ""
    @State private var isSending = false
    @State private var showReportDialog = false
    @State private var showReportSentAlert = false
    @State private var showBlockConfirm = false
    @State private var showUnblockConfirm = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isSendingImage = false
    @State private var fullScreenImageURL: String?

    private var currentUid: String { authViewModel.user?.uid ?? "" }
    private var otherName: String { chat.otherParticipantName(currentUid: currentUid) }
    /// The chat as reflected in ChatsViewModel's live listener, so a block/
    /// unblock made from either side of the conversation shows up here
    /// without needing a dedicated listener on this single doc.
    private var liveChat: Chat { chatsViewModel.chats.first(where: { $0.id == chat.id }) ?? chat }
    private var isBlockedByMe: Bool { liveChat.isBlockedByMe(currentUid: currentUid) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        if !chat.adTitle.isEmpty {
                            adBanner
                        }

                        ForEach(messagesViewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isMine: message.senderId == currentUid,
                                onTapImage: { url in fullScreenImageURL = url }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messagesViewModel.messages) { messages in
                    guard let last = messages.last else { return }
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            if liveChat.isBlocked {
                blockedBanner
            }

            inputBar
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(otherName)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showReportDialog = true
                    } label: {
                        Label("Пожаловаться", systemImage: "exclamationmark.bubble")
                    }

                    if isBlockedByMe {
                        Button {
                            showUnblockConfirm = true
                        } label: {
                            Label("Разблокировать", systemImage: "checkmark.circle")
                        }
                    } else {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Заблокировать", systemImage: "hand.raised")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .confirmationDialog("Причина жалобы", isPresented: $showReportDialog, titleVisibility: .visible) {
            ForEach(reportReasons, id: \.self) { reason in
                Button(reason) {
                    Task {
                        _ = await chatsViewModel.submitReport(
                            chatId: chat.id,
                            reportedUid: chat.otherParticipantId(currentUid: currentUid),
                            reporterId: currentUid,
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
        .alert("Заблокировать собеседника?", isPresented: $showBlockConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Заблокировать", role: .destructive) {
                Task { await chatsViewModel.setBlocked(chatId: chat.id, uid: currentUid, blocked: true) }
            }
        } message: {
            Text("Переписка станет недоступна для отправки сообщений с обеих сторон.")
        }
        .alert("Разблокировать собеседника?", isPresented: $showUnblockConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Разблокировать") {
                Task { await chatsViewModel.setBlocked(chatId: chat.id, uid: currentUid, blocked: false) }
            }
        }
        .alert("Сообщение не отправлено", isPresented: Binding(
            get: { chatsViewModel.errorMessage != nil },
            set: { if !$0 { chatsViewModel.errorMessage = nil } }
        )) {
            Button("Понятно", role: .cancel) { chatsViewModel.errorMessage = nil }
        } message: {
            Text(chatsViewModel.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: Binding(
            get: { fullScreenImageURL != nil },
            set: { if !$0 { fullScreenImageURL = nil } }
        )) {
            if let url = fullScreenImageURL {
                FullScreenImageViewer(imageURLs: [url], selectedIndex: .constant(0))
            }
        }
        .onChange(of: pickerItem) { newItem in
            guard let newItem else { return }
            Task { await sendPickedImage(newItem) }
        }
        .onAppear {
            messagesViewModel.startListening(chatId: chat.id)
            Task { await chatsViewModel.markRead(chatId: chat.id, uid: currentUid) }
            if let user = authViewModel.user {
                Task {
                    await chatsViewModel.syncOwnProfile(
                        chat: chat,
                        uid: currentUid,
                        displayName: user.displayNameOrFallback,
                        photoURL: user.photoURL?.absoluteString
                    )
                }
            }
            if isPushedInTabBar {
                isTabBarHidden.wrappedValue = true
            }
        }
        .onDisappear {
            messagesViewModel.stopListening()
            if isPushedInTabBar {
                isTabBarHidden.wrappedValue = false
            }
        }
    }

    private let reportReasons = ["Спам или реклама", "Мошенничество", "Оскорбления", "Другое"]

    private var blockedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .foregroundColor(Color(hex: "E8352B"))
                .font(.footnote)
            Text(
                isBlockedByMe
                    ? "Вы заблокировали этот чат. Сообщения отправлять нельзя."
                    : "Собеседник ограничил переписку в этом чате."
            )
            .font(.footnote)
            .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .padding(12)
        .background(Color(hex: "E8352B").opacity(0.1))
    }

    private var adBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill")
                .foregroundColor(AppTheme.accent)
                .font(.footnote)
            Text(chat.adTitle)
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(10)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                if isSendingImage {
                    ProgressView().tint(AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                }
            }
            .disabled(liveChat.isBlocked || isSendingImage)

            TextField(
                "",
                text: $draft,
                prompt: Text(liveChat.isBlocked ? "Переписка ограничена" : "Сообщение...").foregroundColor(AppTheme.textSecondary),
                axis: .vertical
            )
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1...4)
            .disabled(liveChat.isBlocked)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.cardBorder, lineWidth: 1))

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(canSend ? AppTheme.accent : AppTheme.accent.opacity(0.4))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.6))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && !liveChat.isBlocked
    }

    private func send() async {
        guard canSend else { return }
        let text = draft
        draft = ""
        isSending = true
        _ = await chatsViewModel.sendMessage(
            chatId: chat.id,
            senderId: currentUid,
            otherUid: chat.otherParticipantId(currentUid: currentUid),
            text: text
        )
        isSending = false
    }

    private func sendPickedImage(_ item: PhotosPickerItem) async {
        guard !liveChat.isBlocked else { return }
        pickerItem = nil
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        isSendingImage = true
        _ = await chatsViewModel.sendImageMessage(
            chatId: chat.id,
            senderId: currentUid,
            otherUid: chat.otherParticipantId(currentUid: currentUid),
            image: image
        )
        isSendingImage = false
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let onTapImage: (String) -> Void

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: message.hasImage && !message.text.isEmpty ? 6 : 0) {
                if message.hasImage, let imageURL = message.imageURL {
                    Button {
                        onTapImage(imageURL)
                    } label: {
                        CachedAsyncImage(urlString: imageURL)
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundColor(isMine ? .white : AppTheme.textPrimary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isMine ? AppTheme.accent : AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isMine ? Color.clear : AppTheme.cardBorder, lineWidth: 1)
            )

            if !isMine { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(
            chat: Chat(
                id: "preview",
                data: [
                    "adId": "1",
                    "adTitle": "Кирпич М-150, поддон",
                    "sellerId": "1",
                    "sellerName": "Андрей Н.",
                    "buyerId": "2",
                    "buyerName": "Мария К.",
                    "participants": ["1", "2"]
                ]
            )!
        )
    }
    .environmentObject(AuthViewModel())
    .environmentObject(ChatsViewModel())
}
