//
//  SubscribeButton.swift
//  erassvet
//

import SwiftUI

/// Plain grey bell icon toggling a subscription, reused on blog posts (feed
/// card + detail) and the seller card on an ad's detail screen. Hidden by
/// callers on the viewer's own content — see each call site's
/// `isOwnContent` check.
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
            Image(systemName: isSubscribed ? "bell.fill" : "bell")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
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
