//
//  MainTabView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth

enum AppTab {
    case feed, chats, favorites, profile
}

/// Lets a deeply-pushed screen (e.g. an open chat) hide MainTabView's custom
/// bottom tab bar so it can occupy the full screen. Defaults to a no-op
/// binding so views presented outside MainTabView's hierarchy (e.g. in a
/// sheet, which already covers the tab bar) are unaffected.
private struct TabBarHiddenKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var isTabBarHidden: Binding<Bool> {
        get { self[TabBarHiddenKey.self] }
        set { self[TabBarHiddenKey.self] = newValue }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    @StateObject private var chatsViewModel = ChatsViewModel()
    @State private var selectedTab: AppTab = .feed
    @State private var showPostAd = false
    @State private var isTabBarHidden = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .feed:
                    FeedView()
                case .chats:
                    ChatsView()
                case .favorites:
                    FavoritesView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isTabBarHidden {
                BottomTabBar(selectedTab: $selectedTab, showPostAd: $showPostAd, unreadCount: chatsViewModel.totalUnreadCount)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .environment(\.isTabBarHidden, $isTabBarHidden)
        .environmentObject(authViewModel)
        .environmentObject(favoritesViewModel)
        .environmentObject(chatsViewModel)
        .sheet(isPresented: $showPostAd) {
            PostAdView().environmentObject(authViewModel)
        }
        .onAppear {
            if let uid = authViewModel.user?.uid {
                favoritesViewModel.startListening(uid: uid)
                chatsViewModel.startListening(uid: uid)
            }
        }
        .onChange(of: authViewModel.user?.uid) { uid in
            if let uid {
                favoritesViewModel.startListening(uid: uid)
                chatsViewModel.startListening(uid: uid)
            } else {
                favoritesViewModel.stopListening()
                chatsViewModel.stopListening()
            }
        }
    }
}

/// A floating, pill-shaped tab bar (glass background, capsule highlight that
/// glides between the selected tab, labels only shown on the active tab)
/// instead of the old edge-to-edge flat bar.
private struct BottomTabBar: View {
    @Binding var selectedTab: AppTab
    @Binding var showPostAd: Bool
    let unreadCount: Int
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 2) {
            TabBarButton(icon: "list.bullet", title: "Лента", tab: .feed, selectedTab: $selectedTab, namespace: tabAnimation)
            TabBarButton(icon: "message", title: "Чаты", tab: .chats, selectedTab: $selectedTab, namespace: tabAnimation, badgeCount: unreadCount)

            Button {
                showPostAd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.accent, Color(hex: "6FA3FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: AppTheme.accent.opacity(0.55), radius: 10, y: 4)
            }
            .offset(y: -12)
            .padding(.horizontal, 2)

            TabBarButton(icon: "heart", title: "Избранное", tab: .favorites, selectedTab: $selectedTab, namespace: tabAnimation)
            TabBarButton(icon: "person", title: "Профиль", tab: .profile, selectedTab: $selectedTab, namespace: tabAnimation)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(AppTheme.card.opacity(0.72)))
                .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.35), radius: 20, y: 8)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }
}

private struct TabBarButton: View {
    let icon: String
    let title: String
    let tab: AppTab
    @Binding var selectedTab: AppTab
    var namespace: Namespace.ID
    var badgeCount: Int = 0

    private var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(AppTheme.accent.opacity(0.16))
                                    .matchedGeometryEffect(id: "tabPill", in: namespace)
                            }
                        }

                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -2)
                    }
                }

                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MainTabView().environmentObject(AuthViewModel())
}
