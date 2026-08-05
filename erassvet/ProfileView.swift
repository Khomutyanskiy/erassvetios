//
//  ProfileView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var myAdsViewModel = MyAdsViewModel()
    @State private var showAuth = false
    @State private var notificationsEnabled = true
    @State private var isMyListingsExpanded = true
    @State private var showHelp = false
    @State private var showAdminPanel = false
    @State private var editingAd: Ad?

    var body: some View {
        content
    }

    private var content: some View {
        Group {
            if authViewModel.isAuthenticated, let user = authViewModel.user {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        PageHeader(title: "Профиль")

                        ProfileHeader(user: user)

                        if authViewModel.isAdmin {
                            Button {
                                showAdminPanel = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "shield.lefthalf.filled")
                                    Text("Административная панель")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                }
                                .foregroundColor(.white)
                                .padding(16)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isMyListingsExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Мои объявления (\(myAdsViewModel.ads.count))")
                                    .font(.title3.bold())
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.subheadline.bold())
                                    .foregroundColor(AppTheme.textSecondary)
                                    .rotationEffect(.degrees(isMyListingsExpanded ? 0 : -90))
                            }
                        }
                        .buttonStyle(.plain)

                        if isMyListingsExpanded {
                            if myAdsViewModel.isLoading {
                                ProgressView()
                                    .tint(AppTheme.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            } else if let error = myAdsViewModel.errorMessage {
                                VStack(spacing: 6) {
                                    Text("Не удалось загрузить объявления")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                            } else if myAdsViewModel.ads.isEmpty {
                                Text("У вас пока нет объявлений")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                VStack(spacing: 14) {
                                    ForEach(myAdsViewModel.ads) { ad in
                                        MyAdRow(ad: ad) {
                                            editingAd = ad
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        Text("Настройки")
                            .font(.title3.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "bell")
                                    .foregroundColor(AppTheme.accent)
                                    .frame(width: 24)
                                Text("Уведомления")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Toggle("", isOn: $notificationsEnabled)
                                    .labelsHidden()
                                    .tint(AppTheme.accent)
                            }
                            .padding(16)

                            Divider().overlay(AppTheme.cardBorder)

                            SettingsRow(icon: "questionmark.circle", title: "Помощь", showChevron: true) {
                                showHelp = true
                            }

                            Divider().overlay(AppTheme.cardBorder)

                            Button {
                                authViewModel.signOut()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    Text("Выйти")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(16)
                            }
                        }
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            } else {
                VStack(spacing: 0) {
                    PageHeader(title: "Профиль")
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 56))
                            .foregroundColor(AppTheme.textSecondary)

                        Text("Вы не авторизованы")
                            .font(.title3.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Войдите, чтобы размещать объявления\nи управлять профилем")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showAuth = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Войти")
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            if let uid = authViewModel.user?.uid {
                myAdsViewModel.startListening(sellerId: uid)
            }
        }
        .onDisappear {
            myAdsViewModel.stopListening()
        }
        .onChange(of: authViewModel.user?.uid) { uid in
            if let uid {
                myAdsViewModel.startListening(sellerId: uid)
            } else {
                myAdsViewModel.stopListening()
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthView().environmentObject(authViewModel)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showAdminPanel) {
            AdminPanelView()
        }
        .sheet(item: $editingAd) { ad in
            PostAdView(existingAd: ad).environmentObject(authViewModel)
        }
    }
}

private struct ProfileHeader: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let user: User
    @State private var showEditProfile = false

    var body: some View {
        Button {
            showEditProfile = true
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 1))

                    if let photoURL = user.photoURL {
                        AsyncImage(url: photoURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Text(user.initials)
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        Text(user.initials)
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayNameOrFallback)
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 4) {
                        if user.isEmailVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: "3FBF7F"))
                        }
                        Text(user.emailOrFallback)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView().environmentObject(authViewModel)
        }
    }
}

private struct MyAdRow: View {
    let ad: Ad
    let onTap: () -> Void

    private var statusColor: Color {
        switch ad.status {
        case .active: return Color(hex: "3FBF7F")
        case .pending: return AppTheme.gold
        case .rejected: return Color(hex: "E8352B")
        case .inactive: return AppTheme.textSecondary
        }
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                thumbnail

                VStack(alignment: .leading, spacing: 6) {
                    Text(ad.title)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Text(ad.status.title)
                            .font(.caption)
                            .foregroundColor(statusColor)

                        Text(ad.priceText)
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.gold)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.caption2)
                        Text("\(ad.views) \(viewsWord(ad.views))")
                            .font(.caption)
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(14)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func viewsWord(_ count: Int) -> String {
        let rem100 = count % 100
        let rem10 = count % 10
        if rem100 >= 11 && rem100 <= 14 { return "просмотров" }
        switch rem10 {
        case 1: return "просмотр"
        case 2, 3, 4: return "просмотра"
        default: return "просмотров"
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let firstURL = ad.imageURLs.first, let url = URL(string: firstURL) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill((AppTheme.categoryColors[ad.category] ?? AppTheme.accent).opacity(0.18))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: ad.iconName)
                    .foregroundColor(AppTheme.categoryColors[ad.category] ?? AppTheme.accent)
                    .font(.system(size: 20))
            )
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.textSecondary)
                        .font(.footnote)
                }
            }
            .padding(16)
        }
    }
}

#Preview {
    ProfileView().environmentObject(AuthViewModel())
}
