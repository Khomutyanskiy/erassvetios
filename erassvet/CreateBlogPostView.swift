//
//  CreateBlogPostView.swift
//  erassvet
//

import SwiftUI
import PhotosUI
import FirebaseAuth

/// Create/edit form reached from Блог's pencil icon (new post) or the edit
/// icon on one's own post. Text + up to 3 photos. Whether the post appears
/// immediately or waits for admin approval depends on the moderation
/// toggle — the user isn't shown that state explicitly, just a neutral
/// confirmation that the post was submitted.
struct CreateBlogPostView: View {
    @ObservedObject var viewModel: BlogViewModel
    let existing: BlogPost?
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    /// Ordered slots — a mix of the post's existing photos (while editing)
    /// and freshly picked ones, in display order. Each thumbnail owns its
    /// own remove button, so any slot can be dropped independently.
    @State private var imageSlots: [BlogImageSlot]
    @State private var pickerItems: [PhotosPickerItem] = []

    private let maxImages = 3

    private var isLoadingAnyImage: Bool {
        imageSlots.contains { if case .loading = $0 { return true }; return false }
    }

    init(viewModel: BlogViewModel, existing: BlogPost? = nil) {
        self.viewModel = viewModel
        self.existing = existing
        _text = State(initialValue: existing?.text ?? "")
        _imageSlots = State(initialValue: existing?.imageURLs.map { BlogImageSlot.existing($0) } ?? [])
    }

    private var isEditing: Bool { existing != nil }

    private var isFormValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    fieldBlock(title: "Текст поста") {
                        TextField("", text: $text, prompt: Text("Что у вас нового?").foregroundColor(AppTheme.textSecondary), axis: .vertical)
                            .lineLimit(4...10)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    fieldBlock(title: "Фото (до 3, необязательно)") {
                        imagePickerBlock
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(isEditing ? "Сохранить" : "Опубликовать")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(isFormValid ? AppTheme.accent : AppTheme.accent.opacity(0.4))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!isFormValid || viewModel.isSaving || isLoadingAnyImage)
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Редактировать пост" : "Новый пост")
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
            .onChange(of: pickerItems) { newItems in
                Task { await appendPickedImages(newItems) }
            }
        }
    }

    private var imagePickerBlock: some View {
        HStack(spacing: 10) {
            ForEach(Array(imageSlots.enumerated()), id: \.offset) { index, slot in
                thumbnail(for: slot)
                    .overlay(alignment: .topTrailing) {
                        if case .loading = slot {
                            // No remove button while it's still decoding —
                            // nothing to remove yet.
                        } else {
                            Button {
                                imageSlots.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding(4)
                        }
                    }
            }

            if imageSlots.count < maxImages {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: maxImages - imageSlots.count, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.card)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))

                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(width: 90, height: 90)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for slot: BlogImageSlot) -> some View {
        switch slot {
        case .existing(let urlString):
            CachedAsyncImage(urlString: urlString)
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        case .picked(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        case .loading:
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.card)
                .frame(width: 90, height: 90)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
                .overlay(ProgressView().tint(AppTheme.accent))
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

    /// Adds a loading placeholder for each newly picked photo right away,
    /// then decodes them concurrently and swaps each placeholder for its
    /// own result as it finishes — so a slow photo doesn't hold up the
    /// others' spinners from resolving.
    private func appendPickedImages(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        let placeholders = items.map { (id: UUID(), item: $0) }
        for placeholder in placeholders {
            imageSlots.append(.loading(placeholder.id))
        }
        pickerItems = []

        await withTaskGroup(of: (UUID, UIImage?).self) { group in
            for placeholder in placeholders {
                group.addTask {
                    let data = try? await placeholder.item.loadTransferable(type: Data.self)
                    return (placeholder.id, data.flatMap { UIImage(data: $0) })
                }
            }
            for await (id, image) in group {
                guard let index = imageSlots.firstIndex(where: {
                    if case .loading(let loadingId) = $0 { return loadingId == id }
                    return false
                }) else { continue }
                if let image {
                    imageSlots[index] = .picked(image)
                } else {
                    imageSlots.remove(at: index)
                }
            }
        }
    }

    private func submit() async {
        guard let user = authViewModel.user else { return }
        let success: Bool
        if let existing {
            success = await viewModel.updateOwnPost(existing, text: text, imageSlots: imageSlots)
        } else {
            let images = imageSlots.compactMap { slot -> UIImage? in
                if case .picked(let image) = slot { return image }
                return nil
            }
            success = await viewModel.createPost(
                authorId: user.uid,
                authorName: user.displayNameOrFallback,
                authorPhotoURL: user.photoURL?.absoluteString,
                text: text,
                images: images
            )
        }
        if success {
            dismiss()
        }
    }
}

#Preview {
    CreateBlogPostView(viewModel: BlogViewModel())
        .environmentObject(AuthViewModel())
}
