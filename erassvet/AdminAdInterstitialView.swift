//
//  AdminAdInterstitialView.swift
//  erassvet
//

import SwiftUI
import PhotosUI

/// Admin-only screen for managing the pool of ad shutter ("рекламная
/// шторка") entries shown right after the splash screen. Multiple entries
/// can exist at once — exactly one is marked active and that's the one
/// shown to users. Reached from AdminPanelView.
struct AdminAdInterstitialView: View {
    @StateObject private var viewModel = AdminAdInterstitialViewModel()
    @State private var isAddingNew = false
    @State private var editingInterstitial: AdInterstitial?
    @State private var pendingDelete: AdInterstitial?
    @State private var isTogglingEnabled = false
    @State private var previewItem: AdInterstitial?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Показывается всем пользователям сразу после заставки при запуске. Активной может быть только одна.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                enabledToggleCard

                Button {
                    isAddingNew = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Добавить шторку")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else if viewModel.interstitials.isEmpty {
                    Text("Шторок пока нет — добавьте первую выше.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.interstitials.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider().overlay(AppTheme.cardBorder)
                            }
                            InterstitialManageRow(
                                item: item,
                                isActive: viewModel.activeId == item.id,
                                onSetActive: { Task { await viewModel.setActive(item.id) } },
                                onPreview: { previewItem = item },
                                onEdit: { editingInterstitial = item },
                                onDelete: { pendingDelete = item }
                            )
                        }
                    }
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Рекламная шторка")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .sheet(isPresented: $isAddingNew) {
            InterstitialFormView(existing: nil, viewModel: viewModel)
        }
        .sheet(item: $editingInterstitial) { item in
            InterstitialFormView(existing: item, viewModel: viewModel)
        }
        .alert("Удалить шторку?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Отмена", role: .cancel) { pendingDelete = nil }
            Button("Удалить", role: .destructive) {
                if let item = pendingDelete {
                    Task { await viewModel.deleteInterstitial(item) }
                }
                pendingDelete = nil
            }
        } message: {
            Text("Если она была активной, показ шторки отключится, пока не выберете другую.")
        }
        .fullScreenCover(item: $previewItem) { item in
            InterstitialPreviewCover(item: item)
        }
    }

    private var enabledToggleCard: some View {
        Toggle(isOn: Binding(
            get: { viewModel.isEnabled },
            set: { newValue in
                isTogglingEnabled = true
                Task {
                    await viewModel.setEnabled(newValue)
                    isTogglingEnabled = false
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Показывать шторку")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(viewModel.isEnabled ? "Активная шторка показывается при запуске." : "Шторка не показывается никому.")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .tint(AppTheme.accent)
        .disabled(isTogglingEnabled)
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

private struct InterstitialManageRow: View {
    let item: AdInterstitial
    let isActive: Bool
    let onSetActive: () -> Void
    let onPreview: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty ? "Без заголовка" : item.title)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                if isActive {
                    Text("Активна")
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: "3FBF7F"))
                }
            }

            Spacer()

            if !isActive {
                Button(action: onSetActive) {
                    Text("Сделать активной")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            Button(action: onPreview) {
                Image(systemName: "eye")
                    .foregroundColor(AppTheme.textSecondary)
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(AppTheme.accent)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if !item.imageURL.isEmpty {
            CachedAsyncImage(urlString: item.imageURL)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.background)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "megaphone.fill").foregroundColor(AppTheme.textSecondary))
        }
    }
}

/// Full-screen preview of a saved interstitial, exactly as end users would
/// see it after the splash screen — reached via the eye icon in the list.
private struct InterstitialPreviewCover: View {
    let item: AdInterstitial
    @Environment(\.dismiss) private var dismiss
    @State private var content: AdInterstitialContent?

    var body: some View {
        ZStack {
            if let content {
                AdInterstitialView(content: content) { dismiss() }
            } else {
                Color.black.opacity(0.6).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .task {
            var c = AdInterstitialContent()
            if !item.title.isEmpty { c.title = item.title }
            if !item.subtitle.isEmpty { c.subtitle = item.subtitle }
            c.linkURL = item.linkURL
            if !item.imageURL.isEmpty {
                c.image = await AdInterstitialContent.loadImage(urlString: item.imageURL)
            }
            content = c
        }
    }
}

/// Add/edit form for a single interstitial entry: title, subtitle, and an
/// optional image uploaded via PhotosPicker (kept as an existing URL if the
/// admin doesn't pick a new one while editing).
private struct InterstitialFormView: View {
    let existing: AdInterstitial?
    @ObservedObject var viewModel: AdminAdInterstitialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var subtitle: String
    @State private var linkURL: String
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var removeExistingImage = false
    @State private var isLoadingImage = false
    @State private var isLoadingPreview = false
    @State private var showPreview = false
    @State private var previewContent: AdInterstitialContent?

    init(existing: AdInterstitial?, viewModel: AdminAdInterstitialViewModel) {
        self.existing = existing
        self.viewModel = viewModel
        _title = State(initialValue: existing?.title ?? "")
        _subtitle = State(initialValue: existing?.subtitle ?? "")
        _linkURL = State(initialValue: existing?.linkURL ?? "")
    }

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    imagePickerBlock

                    fieldBlock(title: "Заголовок") {
                        TextField("", text: $title, prompt: Text("Например, Реклама").foregroundColor(AppTheme.textSecondary))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    fieldBlock(title: "Текст рекламного сообщения") {
                        TextField("", text: $subtitle, prompt: Text("Текст объявления").foregroundColor(AppTheme.textSecondary), axis: .vertical)
                            .lineLimit(3...10)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    fieldBlock(title: "Ссылка (необязательно)") {
                        TextField("", text: $linkURL, prompt: Text("Сайт, Telegram-канал, Instagram и т.д.").foregroundColor(AppTheme.textSecondary))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task { await preview() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoadingPreview {
                                ProgressView().tint(AppTheme.accent)
                            } else {
                                Image(systemName: "eye")
                                Text("Просмотреть")
                                    .font(.subheadline.bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .foregroundColor(AppTheme.accent)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }
                    .disabled(isLoadingPreview || isLoadingImage)

                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(isEditing ? "Сохранить" : "Добавить")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(AppTheme.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(viewModel.isSaving || isLoadingImage)
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Редактировать шторку" : "Новая шторка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .onAppear { viewModel.errorMessage = nil }
            .onChange(of: pickerItem) { newItem in
                guard let newItem else { return }
                removeExistingImage = false
                Task { await loadPickedImage(newItem) }
            }
            .fullScreenCover(isPresented: $showPreview) {
                if let previewContent {
                    AdInterstitialView(content: previewContent) { showPreview = false }
                }
            }
        }
    }

    /// True while there's some image to show — either a freshly picked one
    /// or the item's existing one (as long as the admin hasn't just removed
    /// it) — which is also when the remove ("x") button should appear.
    private var hasVisibleImage: Bool {
        if pickedImage != nil { return true }
        if removeExistingImage { return false }
        return existing.map { !$0.imageURL.isEmpty } ?? false
    }

    private var imagePickerBlock: some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.card)
                        .frame(height: 160)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))

                    if let pickedImage {
                        Image(uiImage: pickedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if hasVisibleImage, let existing, !existing.imageURL.isEmpty {
                        CachedAsyncImage(urlString: existing.imageURL)
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        placeholderIcon
                    }

                    if isLoadingImage {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.4))
                            .frame(height: 160)
                        ProgressView().tint(.white)
                    }
                }
            }

            if hasVisibleImage {
                Button {
                    pickerItem = nil
                    pickedImage = nil
                    removeExistingImage = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(10)
            }
        }
    }

    private var placeholderIcon: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(AppTheme.textSecondary)
            Text("Добавить изображение")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    @ViewBuilder
    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
            content()
        }
    }

    private func loadPickedImage(_ item: PhotosPickerItem) async {
        isLoadingImage = true
        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
            pickedImage = image
        }
        isLoadingImage = false
    }

    private func preview() async {
        isLoadingPreview = true
        var c = AdInterstitialContent()
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { c.title = title }
        if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { c.subtitle = subtitle }
        c.linkURL = linkURL
        if let pickedImage {
            c.image = pickedImage
        } else if hasVisibleImage, let existing, !existing.imageURL.isEmpty {
            c.image = await AdInterstitialContent.loadImage(urlString: existing.imageURL)
        }
        previewContent = c
        isLoadingPreview = false
        showPreview = true
    }

    private func save() async {
        let success: Bool
        if let existing {
            success = await viewModel.updateInterstitial(id: existing.id, title: title, subtitle: subtitle, linkURL: linkURL, image: pickedImage, existingImageURL: existing.imageURL, removeImage: removeExistingImage)
        } else {
            success = await viewModel.addInterstitial(title: title, subtitle: subtitle, linkURL: linkURL, image: pickedImage)
        }
        if success {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AdminAdInterstitialView()
    }
}
