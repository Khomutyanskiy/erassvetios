//
//  AdminModerationView.swift
//  erassvet
//

import SwiftUI

/// Admin-only screen with the moderation on/off toggle plus the queue of
/// ads awaiting approval. Reached from AdminPanelView.
struct AdminModerationView: View {
    @StateObject private var viewModel = AdminModerationViewModel()
    @State private var isTogglingModeration = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                toggleCard

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
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
                    .padding(.vertical, 24)
                } else if viewModel.pendingAds.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Нет объявлений на модерации")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    HStack {
                        Text("На модерации: \(viewModel.pendingAds.count)")
                            .font(.footnote.bold())
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }

                    VStack(spacing: 10) {
                        ForEach(viewModel.pendingAds) { ad in
                            PendingAdRow(
                                ad: ad,
                                isProcessing: viewModel.processingIds.contains(ad.id),
                                onApprove: { Task { await viewModel.approve(adId: ad.id) } },
                                onReject: { Task { await viewModel.reject(adId: ad.id) } }
                            )
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Модерация объявлений")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { viewModel.isModerationEnabled },
                set: { newValue in
                    isTogglingModeration = true
                    Task {
                        await viewModel.setModerationEnabled(newValue)
                        isTogglingModeration = false
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Модерация объявлений")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(
                        viewModel.isModerationEnabled
                            ? "Новые объявления публикуются только после проверки."
                            : "Новые объявления публикуются сразу, без проверки."
                    )
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                }
            }
            .tint(AppTheme.accent)
            .disabled(isTogglingModeration)
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

private struct PendingAdRow: View {
    let ad: Ad
    let isProcessing: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 4) {
                    Text(ad.title)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(ad.sellerDisplayName)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)

                    Text(ad.priceText)
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.gold)
                }

                Spacer()
            }

            if !ad.description.isEmpty {
                Text(ad.description)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(3)
            }

            HStack(spacing: 10) {
                Button {
                    onReject()
                } label: {
                    Label("Отклонить", systemImage: "xmark")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(Color(hex: "E8352B"))
                        .background(Color(hex: "E8352B").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onApprove()
                } label: {
                    Label("Одобрить", systemImage: "checkmark")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(Color(hex: "3FBF7F"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.5 : 1)
            .overlay {
                if isProcessing {
                    ProgressView().tint(AppTheme.accent)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.background)
                .frame(width: 52, height: 52)

            if let urlString = ad.imageURLs.first, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: ad.iconName)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: ad.iconName)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminModerationView()
    }
}
