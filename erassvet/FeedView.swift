//
//  FeedView.swift
//  erassvet
//

import SwiftUI

/// Sort order for the feed. Cases are ordered as they should appear in the menu.
enum FeedSortOption: String, CaseIterable, Identifiable {
    case newest = "Сначала новые"
    case oldest = "Сначала старые"
    case priceAsc = "Сначала дешевле"
    case priceDesc = "Сначала дороже"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        case .priceAsc: return "arrow.up.circle"
        case .priceDesc: return "arrow.down.circle"
        }
    }
}

struct FeedView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var adsListViewModel = AdsListViewModel()
    @StateObject private var categoriesViewModel = CategoriesViewModel()
    @State private var selectedCategory = "Все"
    @State private var selectedDealType = "Все"
    @State private var searchText = ""
    @State private var sortOption: FeedSortOption = .newest
    @State private var showAuth = false
    @State private var showAllCategories = false
    @State private var showSearch = false
    @State private var showFavorites = false

    private var displayCategories: [AppCategory] {
        [.allFilter] + categoriesViewModel.categories
    }

    /// Matches title *and* description (previously title-only).
    private var filteredAds: [Ad] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)

        let filtered = adsListViewModel.ads.filter { ad in
            guard !authViewModel.blockedUserIds.contains(ad.sellerId) else { return false }
            let matchesCategory = selectedCategory == "Все" || ad.category == selectedCategory
            let matchesDealType = selectedDealType == "Все" || ad.dealType.title == selectedDealType
            let matchesSearch = trimmedSearch.isEmpty
                || ad.title.localizedCaseInsensitiveContains(trimmedSearch)
                || ad.description.localizedCaseInsensitiveContains(trimmedSearch)

            return matchesCategory && matchesDealType && matchesSearch
        }

        switch sortOption {
        case .newest:
            return filtered.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldest:
            return filtered.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .priceAsc:
            return filtered.sorted { ($0.price ?? .greatestFiniteMagnitude) < ($1.price ?? .greatestFiniteMagnitude) }
        case .priceDesc:
            return filtered.sorted { ($0.price ?? -1) > ($1.price ?? -1) }
        }
    }

    /// Collapsing the filter panel clears every active filter — search,
    /// category, deal type, and sort — so the filter only ever applies while
    /// it's visibly expanded, never silently in the background.
    private func resetFilters() {
        searchText = ""
        selectedCategory = "Все"
        selectedDealType = "Все"
        sortOption = .newest
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeader(
                        title: "Лента",
                        trailingIcon: "magnifyingglass",
                        trailingAction: {
                            withAnimation {
                                showSearch.toggle()
                                if !showSearch {
                                    resetFilters()
                                }
                            }
                        },
                        secondaryTrailingIcon: "heart",
                        secondaryTrailingAction: { showFavorites = true }
                    )
                    .padding(.top, 8)

                    // Search field and the category/deal-type filters are one
                    // unit — the magnifier in the header reveals and hides
                    // all of them together.
                    if showSearch {
                        VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(AppTheme.textSecondary)
                                TextField("", text: $searchText, prompt: Text("Поиск по объявлениям...").foregroundColor(AppTheme.textSecondary))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding(14)
                            .background(AppTheme.searchBarBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                        }

                        HStack(spacing: 10) {
                            Button {
                                showAllCategories = true
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .frame(width: 32, height: 32)
                                    .background(AppTheme.card)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 1))
                            }

                            Menu {
                                ForEach(FeedSortOption.allCases) { option in
                                    Button {
                                        sortOption = option
                                    } label: {
                                        Label(option.rawValue, systemImage: option.icon)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .frame(width: 32, height: 32)
                                    .background(AppTheme.card)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 1))
                            }

                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(displayCategories) { category in
                                            CategoryChip(
                                                title: category.title,
                                                isSelected: selectedCategory == category.title
                                            )
                                            .id(category.title)
                                            .onTapGesture {
                                                selectedCategory = category.title
                                            }
                                        }
                                    }
                                }
                                .onChange(of: selectedCategory) { newValue in
                                    withAnimation {
                                        proxy.scrollTo(newValue, anchor: .center)
                                    }
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(["Все"] + AdDealType.allCases.map(\.title), id: \.self) { title in
                                    CategoryChip(
                                        title: title,
                                        isSelected: selectedDealType == title,
                                        tint: AdDealType(rawValue: title).flatMap { AppTheme.dealTypeColors[$0] } ?? AppTheme.accent
                                    )
                                    .onTapGesture {
                                        selectedDealType = title
                                    }
                                }
                            }
                        }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if adsListViewModel.isLoading {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if let error = adsListViewModel.errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Не удалось загрузить объявления")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else if filteredAds.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Пока нет объявлений")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(filteredAds) { ad in
                                AdCardRow(ad: ad)
                            }
                        }
                    }

                    if !authViewModel.isAuthenticated {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Разместите объявление бесплатно")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Регистрация займёт меньше минуты")
                                    .font(.footnote)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            Button {
                                showAuth = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Войти")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.accent)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(16)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Ad.self) { ad in
                AdDetailView(ad: ad)
            }
            .sheet(isPresented: $showAuth) {
                AuthView().environmentObject(authViewModel)
            }
            .sheet(isPresented: $showAllCategories) {
                CategoryPickerSheet(categories: displayCategories, selectedCategory: $selectedCategory)
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView()
                    .environmentObject(authViewModel)
            }
            .onAppear {
                adsListViewModel.startListening()
                categoriesViewModel.startListening()
            }
            .onDisappear {
                adsListViewModel.stopListening()
                categoriesViewModel.stopListening()
            }
        }
    }
}

private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Sheet with every category on the page — reached via the icon before the
/// "Все" chip, since the horizontal chip row only shows a few at a time.
/// Sized to fit its own content instead of taking up the full screen height.
private struct CategoryPickerSheet: View {
    let categories: [AppCategory]
    @Binding var selectedCategory: String
    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Категории")
                    .font(.title3.bold())
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.card)
                            .clipShape(Circle())
                    }
                }
            }

            FlowLayout(spacing: 10) {
                ForEach(categories) { category in
                    CategoryChip(
                        title: category.title,
                        isSelected: selectedCategory == category.title
                    )
                    .fixedSize()
                    .onTapGesture {
                        selectedCategory = category.title
                        dismiss()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        // Measure at the content's *intrinsic* height. Without fixedSize the
        // container adopts the sheet's current detent height, which then feeds
        // back into the detent and the sheet collapses to the bottom edge.
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(SheetHeightKey.self) { newHeight in
            guard newHeight > 0 else { return }
            contentHeight = newHeight
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

/// Simple wrapping "tag cloud" layout — each chip keeps its own natural,
/// single-line width and wraps to the next row only when it doesn't fit,
/// unlike LazyVGrid's equal-width columns which forced long titles like
/// "Строительство" to wrap onto two lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth > 0 && lineWidth + spacing + size.width > maxWidth {
                totalWidth = max(totalWidth, lineWidth)
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += (lineWidth > 0 ? spacing : 0) + size.width
            lineHeight = max(lineHeight, size.height)
        }
        totalWidth = max(totalWidth, lineWidth)
        totalHeight += lineHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x - bounds.minX + size.width > maxWidth {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    var tint: Color = AppTheme.accent

    var body: some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? tint : AppTheme.card)
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : AppTheme.cardBorder, lineWidth: 1)
            )
    }
}

#Preview {
    FeedView()
        .environmentObject(AuthViewModel())
        .environmentObject(FavoritesViewModel())
}
