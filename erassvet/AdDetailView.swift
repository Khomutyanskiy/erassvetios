//
//  AdDetailView.swift
//  erassvet
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import FirebaseAuth
#endif

struct AdDetailView: View {
    let ad: Ad

    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject private var chatsViewModel: ChatsViewModel
    @StateObject private var adsViewModel = AdsViewModel()
    @StateObject private var ratingViewModel = SellerRatingViewModel()
    @State private var showAuth = false
    @State private var showOwnAdAlert = false
    @State private var activeChat: Chat?
    @State private var isStartingChat = false
    @State private var selectedImageIndex = 0
    @State private var showFullScreenImages = false
    /// Set when a contact couldn't be opened directly and was copied instead.
    @State private var copiedContactValue: String?

    private var isFavorite: Bool { favoritesViewModel.isFavorite(ad.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                imagePlaceholder

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(ad.title)
                            .font(.title2.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()

                        favoriteButton
                    }

                    Text(ad.priceText)
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.gold)

                    HStack(spacing: 10) {
                        Text(ad.category)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background((AppTheme.categoryColors[ad.category] ?? AppTheme.accent).opacity(0.18))
                            .foregroundColor(AppTheme.categoryColors[ad.category] ?? AppTheme.accent)
                            .clipShape(Capsule())

                        Text(ad.dealType.title)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background((AppTheme.dealTypeColors[ad.dealType] ?? AppTheme.accent).opacity(0.18))
                            .foregroundColor(AppTheme.dealTypeColors[ad.dealType] ?? AppTheme.accent)
                            .clipShape(Capsule())

                        if !ad.timeAgoText.isEmpty {
                            Text(ad.timeAgoText)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Label(ad.viewsText, systemImage: "eye")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        if !isOwnAd {
                            ratingButton
                        } else if ratingViewModel.rating > 0 {
                            ratingBadge
                        }
                    }
                }

                if !ad.addressText.isEmpty || ad.hasCoordinates {
                    addressCard
                }

                if !ad.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Описание")
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)
                        Text(ad.description)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                }

                // When the seller specified a contact just for this ad, it
                // replaces both the seller card and their profile contacts.
                if let adContact = ad.adContactItem {
                    adContactCard(adContact)
                } else {
                    sellerCard

                    if !ad.contacts.items.isEmpty {
                        contactsCard
                    }
                }

                contactButton
            }
            .padding(16)
            .padding(.bottom, 80)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAuth) {
            AuthView().environmentObject(authViewModel)
        }
        .sheet(item: $activeChat) { chat in
            NavigationStack {
                ChatDetailView(chat: chat)
            }
            .environmentObject(authViewModel)
            .environmentObject(chatsViewModel)
        }
        .alert("Это ваше объявление", isPresented: $showOwnAdAlert) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Нельзя написать самому себе.")
        }
        .alert("Скопировано", isPresented: Binding(
            get: { copiedContactValue != nil },
            set: { if !$0 { copiedContactValue = nil } }
        )) {
            Button("Понятно", role: .cancel) { copiedContactValue = nil }
        } message: {
            Text("\(copiedContactValue ?? "") — не удалось открыть на этом устройстве, контакт скопирован в буфер обмена.")
        }
        .task(id: ad.id) {
            let viewerId = authViewModel.user?.uid ?? ViewerIdentity.id
            await adsViewModel.registerUniqueView(adId: ad.id, viewerId: viewerId)
        }
        .task(id: ad.sellerId) {
            ratingViewModel.startListening(sellerId: ad.sellerId, currentUid: authViewModel.user?.uid)
        }
        .onDisappear {
            ratingViewModel.stopListening()
        }
    }

    @ViewBuilder
    private var imagePlaceholder: some View {
        if ad.hasImage {
            TabView(selection: $selectedImageIndex) {
                ForEach(Array(ad.imageURLs.enumerated()), id: \.offset) { index, urlString in
                    AsyncImage(url: URL(string: urlString)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if phase.error != nil {
                            imageFallback
                        } else {
                            ProgressView().tint(AppTheme.accent)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFullScreenImages = true
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.cardBorder, lineWidth: 1))
            .fullScreenCover(isPresented: $showFullScreenImages) {
                FullScreenImageViewer(imageURLs: ad.imageURLs, selectedIndex: $selectedImageIndex)
            }
        }
        // Объявления без фото просто не показывают этот блок — вместо
        // пустого плейсхолдера карточка начинается сразу с названия.
    }

    /// Shown only when a photo *was* uploaded but failed to load (broken
    /// link, no network) — never for ads that simply have no photos.
    private var imageFallback: some View {
        VStack(spacing: 8) {
            Image(systemName: ad.iconName)
                .font(.system(size: 40))
                .foregroundColor(AppTheme.categoryColors[ad.category] ?? AppTheme.accent)
            Text("Фото пока недоступно")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background((AppTheme.categoryColors[ad.category] ?? AppTheme.accent).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Адрес")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            if !ad.addressText.isEmpty {
                Label(ad.addressText, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }

            if !ad.note.isEmpty {
                Text(ad.note)
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
            }

            if ad.hasCoordinates {
                Button {
                    openInYandexMaps()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                        Text("Открыть в Яндекс.Картах")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.accent)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var favoriteButton: some View {
        Button {
            toggleFavorite()
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isFavorite ? .red : AppTheme.textSecondary)
                .padding(10)
                .background(AppTheme.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 1))
        }
    }

    private func toggleFavorite() {
        guard let uid = authViewModel.user?.uid else {
            showAuth = true
            return
        }
        Task { await favoritesViewModel.toggleFavorite(adId: ad.id, uid: uid) }
    }

    private func openInYandexMaps() {
        guard let lat = ad.latitude, let lon = ad.longitude else { return }
        guard let url = URL(string: "https://yandex.ru/maps/?pt=\(lon),\(lat)&z=17&l=map") else { return }
        UIApplication.shared.open(url)
    }

    private var sellerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(String(ad.sellerDisplayName.prefix(1)).uppercased())
                    .font(.headline.bold())
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ad.sellerDisplayName)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text("Продавец")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var isOwnAd: Bool { authViewModel.user?.uid == ad.sellerId }

    /// Thumbs up / thumbs down pair plus the running total. Once this viewer
    /// has voted either way, both buttons lock into a read-only state
    /// showing which one they picked (no switching, no double-voting).
    private var ratingButton: some View {
        HStack(spacing: 6) {
            Button {
                Task { await rateSeller(value: 1) }
            } label: {
                Image(systemName: ratingViewModel.myVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .foregroundColor(ratingViewModel.myVote == 1 ? .white : AppTheme.accent)
            .frame(width: 26, height: 26)
            .background(ratingViewModel.myVote == 1 ? AppTheme.accent : AppTheme.accent.opacity(0.14))
            .clipShape(Circle())

            Text("\(ratingViewModel.rating)")
                .font(.footnote.bold())
                .foregroundColor(ratingViewModel.rating < 0 ? .red : AppTheme.textPrimary)
                .frame(minWidth: 18)

            Button {
                Task { await rateSeller(value: -1) }
            } label: {
                Image(systemName: ratingViewModel.myVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
            .foregroundColor(ratingViewModel.myVote == -1 ? .white : .red)
            .frame(width: 26, height: 26)
            .background(ratingViewModel.myVote == -1 ? Color.red : Color.red.opacity(0.14))
            .clipShape(Circle())

            if ratingViewModel.isSubmitting {
                ProgressView().tint(AppTheme.accent).scaleEffect(0.7)
            }
        }
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.accent.opacity(0.08))
        .clipShape(Capsule())
        .disabled(ratingViewModel.hasVoted || ratingViewModel.isSubmitting)
    }

    /// Read-only version shown to the seller viewing their own ad.
    private var ratingBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: ratingViewModel.rating < 0 ? "hand.thumbsdown.fill" : "hand.thumbsup.fill")
            Text("\(ratingViewModel.rating)")
                .font(.footnote.bold())
        }
        .font(.footnote)
        .foregroundColor(ratingViewModel.rating < 0 ? .red : AppTheme.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background((ratingViewModel.rating < 0 ? Color.red : AppTheme.accent).opacity(0.14))
        .clipShape(Capsule())
    }

    private func rateSeller(value: Int) async {
        guard let uid = authViewModel.user?.uid else {
            showAuth = true
            return
        }
        await ratingViewModel.rate(sellerId: ad.sellerId, currentUid: uid, value: value)
    }

    /// Shown instead of the seller card + profile contacts when the ad has
    /// its own contact person: name on top, tappable contact value below.
    private func adContactCard(_ item: ContactItem) -> some View {
        Button {
            openContact(item)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(item.tint.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(item.tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(item.value)
                        .font(.footnote)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(16)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var contactsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Контакты")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(ad.contacts.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().overlay(AppTheme.cardBorder)
                    }
                    Button {
                        openContact(item)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(item.tint.opacity(0.18))
                                    .frame(width: 36, height: 36)
                                Image(systemName: item.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(item.tint)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                                Text(item.value)
                                    .font(.subheadline.bold())
                                    .foregroundColor(AppTheme.textPrimary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(14)
                    }
                }
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func openContact(_ item: ContactItem) {
        guard let url = URL(string: item.urlString) else {
            copyToClipboard(item.value)
            return
        }
        // `tel:` isn't supported everywhere (iOS Simulator, iPad without
        // cellular) — falling back to the clipboard keeps the tap useful
        // instead of silently doing nothing.
        UIApplication.shared.open(url, options: [:]) { didOpen in
            if !didOpen {
                copyToClipboard(item.value)
            }
        }
    }

    private func copyToClipboard(_ value: String) {
        UIPasteboard.general.string = value
        copiedContactValue = value
    }

    private var contactButton: some View {
        Button {
            Task { await openChatWithSeller() }
        } label: {
            HStack(spacing: 6) {
                if isStartingChat {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "message.fill")
                    Text("Написать продавцу")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(AppTheme.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isStartingChat)
    }

    private func openChatWithSeller() async {
        guard let user = authViewModel.user else {
            showAuth = true
            return
        }
        if user.uid == ad.sellerId {
            showOwnAdAlert = true
            return
        }
        isStartingChat = true
        let chat = await chatsViewModel.startOrGetChat(
            adId: ad.id,
            adTitle: ad.title,
            adImageURL: ad.imageURLs.first,
            sellerId: ad.sellerId,
            sellerName: ad.sellerDisplayName,
            sellerPhotoURL: ad.sellerPhotoURL,
            buyerId: user.uid,
            buyerName: user.displayNameOrFallback,
            buyerPhotoURL: user.photoURL?.absoluteString
        )
        isStartingChat = false
        activeChat = chat
    }
}

#Preview {
    NavigationStack {
        AdDetailView(
            ad: Ad(
                id: "preview",
                data: [
                    "title": "Кирпич М-150, поддон",
                    "category": "Строительство",
                    "sellerId": "1",
                    "sellerName": "Андрей Н.",
                    "price": 18500.0,
                    "street": "ул. Строителей",
                    "house": "12",
                    "description": "Продаю кирпич М-150, поддон 200 шт. Самовывоз."
                ]
            )!
        )
    }
    .environmentObject(AuthViewModel())
    .environmentObject(FavoritesViewModel())
    .environmentObject(ChatsViewModel())
}
