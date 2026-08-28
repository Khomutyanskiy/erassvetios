//
//  SubscribeButton.swift
//  erassvet
//

import SwiftUI

/// "Подписаться"/"Подписан" pill with a live subscriber count, reused on
/// blog posts (feed card + detail) and the seller card on an ad's detail
/// screen. Hidden by callers on the viewer's own content — see each call
/// site's `isOwnContent` check.
struct SubscribeButton: View {
    let authorId: String
    var onRequireAuth: (() -> Void)? = nil

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var subscriptionViewModel = AuthorSubscriptionViewModel()
    @State private var isSubmitting = false

    private var isSubscribed: Bool { authViewModel.isSubscribed(authorId) }

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isSubscribed ? "bell.fill" : "bell")
                Text(isSubscribed ? "Подписан" : "Подписаться")
                if subscriptionViewModel.subscribersCount > 0 {
                    Text("· \(subscriptionViewModel.subscribersCount)")
                }
            }
            .font(.caption.bold())
            .foregroundColor(isSubscribed ? AppTheme.textSecondary : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSubscribed ? AppTheme.card : AppTheme.accent)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSubscribed ? AppTheme.cardBorder : Color.clear, lineWidth: 1))
        }
        .disabled(isSubmitting)
        .onAppear { subscriptionViewModel.startListening(authorId: authorId) }
        .onDisappear { subscriptionViewModel.stopListening() }
    }

    private func toggle() {
        guard authViewModel.user != nil else {
            onRequireAuth?()
            return
        }
        Task {
            isSubmitting = true
            if isSubscribed {
                await authViewModel.unsubscribeFromAuthor(authorId)
            } else {
                await authViewModel.subscribeToAuthor(authorId)
            }
            isSubmitting = false
        }
    }
}
