//
//  AdCardRow.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Reusable ad summary card used in the Лента and Избранное lists.
/// Tapping the card navigates to the ad's detail screen (requires an
/// ancestor NavigationStack with `.navigationDestination(for: Ad.self)`);
/// the heart button toggles the ad in/out of favorites independently —
/// including the viewer's own ads.
struct AdCardRow: View {
    let ad: Ad

    @EnvironmentObject private var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showAuth = false
    /// One-shot (non-listening) read of the seller's rating, just for this
    /// card — a full `SellerRatingViewModel` listener per row would be too
    /// heavy for a scrolling list.
    @State private var sellerRating: Int = 0

    private var isFavorite: Bool { favoritesViewModel.isFavorite(ad.id) }

    var body: some View {
        HStack(spacing: 14) {
            NavigationLink(value: ad) {
                HStack(spacing: 14) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 6) {
                        Text(ad.title)
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        HStack(spacing: 6) {
                            Text(ad.category)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((AppTheme.colorForCategory(ad.category)).opacity(0.18))
                                .foregroundColor(AppTheme.colorForCategory(ad.category))
                                .clipShape(Capsule())

                            Text(ad.dealType.title)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((AppTheme.dealTypeColors[ad.dealType] ?? AppTheme.accent).opacity(0.18))
                                .foregroundColor(AppTheme.dealTypeColors[ad.dealType] ?? AppTheme.accent)
                                .clipShape(Capsule())
                        }

                        HStack {
                            Text(ad.priceText)
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.gold)

                            if sellerRating != 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: sellerRating < 0 ? "hand.thumbsdown.fill" : "hand.thumbsup.fill")
                                        .font(.system(size: 10))
                                    Text("\(sellerRating)")
                                        .font(.caption2.bold())
                                }
                                .foregroundColor(sellerRating < 0 ? .red : AppTheme.accent)
                            }

                            Spacer()
                            Text(ad.timeAgoText)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if ad.sellerId != authViewModel.user?.uid {
                SubscribeButton(authorId: ad.sellerId, onRequireAuth: { showAuth = true })
                    .padding(8)
                    .background(AppTheme.background.opacity(0.6))
                    .clipShape(Circle())
            }

            Button {
                toggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFavorite ? .red : AppTheme.textSecondary)
                    .padding(8)
                    .background(AppTheme.background.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .sheet(isPresented: $showAuth) {
            AuthView().environmentObject(authViewModel)
        }
        .task(id: ad.sellerId) {
            let doc = try? await Firestore.firestore()
                .collection("user_public")
                .document(ad.sellerId)
                .getDocument()
            sellerRating = doc?.data()?["rating"] as? Int ?? 0
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let firstURL = ad.imageURLs.first, let url = URL(string: firstURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    thumbnailPlaceholder
                case .empty:
                    thumbnailLoading
                @unknown default:
                    thumbnailPlaceholder
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill((AppTheme.colorForCategory(ad.category)).opacity(0.25))
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: ad.iconName)
                    .foregroundColor(AppTheme.colorForCategory(ad.category))
                    .font(.system(size: 22))
            )
    }

    private var thumbnailLoading: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.card)
            .frame(width: 64, height: 64)
            .overlay(
                ProgressView()
                    .tint(AppTheme.textSecondary)
                    .scaleEffect(0.75)
            )
    }

    private func toggleFavorite() {
        guard let uid = authViewModel.user?.uid else {
            showAuth = true
            return
        }
        Task { await favoritesViewModel.toggleFavorite(adId: ad.id, uid: uid) }
    }
}
