//
//  AdCardRow.swift
//  erassvet
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Reusable ad summary card used in the Лента and Избранное lists.
/// Tapping anywhere on the card navigates to the ad's detail screen
/// (requires an ancestor NavigationStack with `.navigationDestination(for:
/// Ad.self)`). The bell (subscribe to author) and heart (favorite) in the
/// bottom-right corner are added via `.overlay` *after* the NavigationLink
/// rather than nested inside its label, so they stay independently
/// tappable without breaking the card's own tap-to-navigate.
struct AdCardRow: View {
    let ad: Ad

    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var favoritesViewModel: FavoritesViewModel

    /// One-shot (non-listening) read of the seller's rating, just for this
    /// card — a full `SellerRatingViewModel` listener per row would be too
    /// heavy for a scrolling list.
    @State private var sellerRating: Int = 0
    @State private var showAuth = false

    private var displayPriceText: String {
        ad.priceText == "Договорная" ? "Цена договорная" : ad.priceText
    }

    private var isOwnAd: Bool { authViewModel.user?.uid == ad.sellerId }
    private var isFavorite: Bool { favoritesViewModel.isFavorite(ad.id) }

    var body: some View {
        NavigationLink(value: ad) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ad.title)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(ad.category)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.textSecondary.opacity(0.15))
                            .foregroundColor(AppTheme.textSecondary)
                            .clipShape(Capsule())

                        Text(ad.dealType.title)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.textSecondary.opacity(0.15))
                            .foregroundColor(AppTheme.textSecondary)
                            .clipShape(Capsule())
                    }

                    HStack {
                        Text(displayPriceText)
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)

                        if sellerRating != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: sellerRating < 0 ? "hand.thumbsdown.fill" : "hand.thumbsup.fill")
                                    .font(.system(size: 10))
                                Text("\(sellerRating)")
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(sellerRating < 0 ? .red : AppTheme.textSecondary)
                        }

                        Label(ad.timeAgoText, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Overlaid, not nested inside the NavigationLink's label above — a
        // control placed *inside* the label can't reliably receive its own
        // taps (the NavigationLink swallows them), but an `.overlay` is
        // composited as a separate layer on top, so these get first dibs on
        // touches within their own small frame while everywhere else still
        // triggers navigation.
        .overlay(alignment: .bottomTrailing) {
            if !isOwnAd {
                HStack(spacing: 16) {
                    SubscribeButton(authorId: ad.sellerId, onRequireAuth: { showAuth = true })
                    favoriteButton
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(AppTheme.colorForCategory(ad.category))
                .frame(width: 10, height: 10)
        }
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .task(id: ad.sellerId) {
            let doc = try? await Firestore.firestore()
                .collection("user_public")
                .document(ad.sellerId)
                .getDocument()
            sellerRating = doc?.data()?["rating"] as? Int ?? 0
        }
        .sheet(isPresented: $showAuth) {
            AuthView().environmentObject(authViewModel)
        }
    }

    private var favoriteButton: some View {
        Button {
            toggleFavorite()
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.subheadline)
                .foregroundColor(isFavorite ? .red : AppTheme.textSecondary)
        }
    }

    private func toggleFavorite() {
        guard let uid = authViewModel.user?.uid else {
            showAuth = true
            return
        }
        Task { await favoritesViewModel.toggleFavorite(adId: ad.id, uid: uid) }
    }
}
