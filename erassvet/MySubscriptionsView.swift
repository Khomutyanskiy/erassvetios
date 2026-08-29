//
//  MySubscriptionsView.swift
//  erassvet
//

import SwiftUI
import FirebaseFirestore

/// One author's section in `MySubscriptionsView` — their display name plus
/// every active ad of theirs, so it reads like "Иван Петров" followed by
/// his listings rather than one flat, unlabeled ad list.
private struct AuthorAdsGroup: Identifiable {
    let authorId: String
    var authorName: String
    let ads: [Ad]
    var id: String { authorId }
}

/// Sheet opened from the bell icon on the Feed header — shows every author
/// the current user is subscribed to, each as a named section, with their
/// active ads listed underneath using the same `AdCardRow` as the main
/// feed. Reuses `AdsListViewModel`'s live "ads" listener and filters
/// client-side, the same pattern `FeedView` already uses for blocked-user
/// filtering; author display names are resolved separately from the public
/// "user_public" docs.
struct MySubscriptionsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var adsListViewModel = AdsListViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var authorNames: [String: String] = [:]

    private var groups: [AuthorAdsGroup] {
        let ads = adsListViewModel.ads.filter { authViewModel.subscribedAuthorIds.contains($0.sellerId) }
        let bySeller = Dictionary(grouping: ads, by: \.sellerId)
        return bySeller.map { authorId, ads in
            AuthorAdsGroup(
                authorId: authorId,
                authorName: authorNames[authorId] ?? "Пользователь",
                ads: ads.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            )
        }
        .sorted { $0.authorName.localizedCaseInsensitiveCompare($1.authorName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if adsListViewModel.isLoading && groups.isEmpty {
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
                        text: "У авторов, на которых вы подписаны, пока нет объявлений"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(groups) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.authorName)
                                        .font(.headline)
                                        .foregroundColor(AppTheme.textPrimary)

                                    VStack(spacing: 12) {
                                        ForEach(group.ads) { ad in
                                            AdCardRow(ad: ad)
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
            .navigationDestination(for: Ad.self) { ad in
                AdDetailView(ad: ad)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .onAppear { adsListViewModel.startListening() }
        .onDisappear { adsListViewModel.stopListening() }
        .task(id: authViewModel.subscribedAuthorIds) {
            await loadAuthorNames()
        }
    }

    private func loadAuthorNames() async {
        let missingIds = authViewModel.subscribedAuthorIds.subtracting(authorNames.keys)
        guard !missingIds.isEmpty else { return }
        var loaded: [String: String] = [:]
        await withTaskGroup(of: (String, String?).self) { group in
            for id in missingIds {
                group.addTask {
                    let doc = try? await Firestore.firestore().collection("user_public").document(id).getDocument()
                    let name = (doc?.data()?["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    return (id, name)
                }
            }
            for await (id, name) in group {
                loaded[id] = name ?? "Пользователь"
            }
        }
        authorNames.merge(loaded) { _, new in new }
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
    MySubscriptionsView()
        .environmentObject(AuthViewModel())
        .environmentObject(FavoritesViewModel())
}
