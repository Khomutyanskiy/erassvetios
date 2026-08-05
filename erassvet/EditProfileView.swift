//
//  EditProfileView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct EditProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var contacts = UserContacts()
    @State private var isLoadingContacts = true
    @State private var isSaving = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 76, height: 76)

                                if let photoURL = authViewModel.user?.photoURL {
                                    AsyncImage(url: photoURL) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            Text(initials)
                                                .font(.title2.bold())
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(width: 76, height: 76)
                                    .clipShape(Circle())
                                } else {
                                    Text(initials)
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                }

                                if isUploadingAvatar {
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                        .frame(width: 76, height: 76)
                                    ProgressView().tint(.white)
                                } else {
                                    Circle()
                                        .fill(AppTheme.accent)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                        )
                                        .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
                                        .offset(x: 26, y: 26)
                                }
                            }
                        }
                        .disabled(isUploadingAvatar)
                        .buttonStyle(.plain)
                        .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Имя")
                                .font(.footnote)
                                .foregroundColor(AppTheme.textSecondary)

                            TextField("", text: $name, prompt: Text("Введите имя").foregroundColor(AppTheme.textSecondary))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(14)
                                .background(AppTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Контакты")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Эти данные увидят покупатели в ваших объявлениях")
                                .font(.footnote)
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ContactField(
                                icon: "envelope.fill",
                                tint: AppTheme.accent,
                                title: "Email",
                                placeholder: "По умолчанию из аккаунта",
                                text: $contacts.email
                            )

                            ContactField(
                                icon: "phone.fill",
                                tint: Color(hex: "3FBF7F"),
                                title: "Телефон",
                                placeholder: "+7 900 000-00-00",
                                text: $contacts.phone,
                                keyboardType: .phonePad
                            )

                            ContactField(
                                icon: "paperplane.fill",
                                tint: Color(hex: "2AABEE"),
                                title: "Telegram",
                                placeholder: "@username",
                                text: $contacts.telegram,
                                autocapitalization: false
                            )

                            ContactField(
                                icon: "message.fill",
                                tint: Color(hex: "25D366"),
                                title: "WhatsApp",
                                placeholder: "+7 900 000-00-00",
                                text: $contacts.whatsapp,
                                keyboardType: .phonePad
                            )

                            ContactField(
                                icon: "bubble.left.and.bubble.right.fill",
                                tint: Color(hex: "8E6EF0"),
                                title: "MAX",
                                placeholder: "@username",
                                text: $contacts.max,
                                autocapitalization: false
                            )

                            ForEach($contacts.other) { $item in
                                CustomContactField(item: $item) {
                                    contacts.other.removeAll { $0.id == item.id }
                                }
                            }

                            Button {
                                contacts.other.append(CustomContact())
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Добавить другой контакт")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.accent)
                            }
                            .padding(.top, 4)
                        }

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Сохранить")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(AppTheme.accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isSaving || isLoadingContacts)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Редактировать профиль")
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
        }
        .task {
            if name.isEmpty {
                name = authViewModel.user?.displayName ?? ""
            }
            authViewModel.errorMessage = nil
            contacts = await authViewModel.loadContacts()
            isLoadingContacts = false
        }
        .onChange(of: avatarPickerItem) { newItem in
            guard let newItem else { return }
            Task { await uploadAvatar(from: newItem) }
        }
    }

    private func uploadAvatar(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            authViewModel.errorMessage = "Не удалось загрузить выбранное фото."
            return
        }
        isUploadingAvatar = true
        _ = await authViewModel.uploadAvatar(image)
        isUploadingAvatar = false
        avatarPickerItem = nil
    }

    private var initials: String {
        authViewModel.user?.initials ?? "?"
    }

    private func save() async {
        isSaving = true
        let nameUpdated = await authViewModel.updateDisplayName(name)
        let nameError = authViewModel.errorMessage
        let contactsSaved = await authViewModel.saveContacts(contacts)
        let contactsError = authViewModel.errorMessage
        isSaving = false
        if nameUpdated && contactsSaved {
            dismiss()
        } else {
            authViewModel.errorMessage = contactsError ?? nameError ?? "Не удалось сохранить изменения."
        }
    }
}

private struct ContactField: View {
    let icon: String
    let tint: Color
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(AppTheme.textSecondary.opacity(0.6)))
                    .foregroundColor(AppTheme.textPrimary)
                    .keyboardType(keyboardType)
                    .autocapitalization(autocapitalization ? .sentences : .none)
                    .disableAutocorrection(!autocapitalization)
            }
        }
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

private struct CustomContactField: View {
    @Binding var item: CustomContact
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.textSecondary.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("", text: $item.label, prompt: Text("Название (например, ВКонтакте)").foregroundColor(AppTheme.textSecondary.opacity(0.6)))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                TextField("", text: $item.value, prompt: Text("Ссылка или контакт").foregroundColor(AppTheme.textSecondary.opacity(0.6)))
                    .foregroundColor(AppTheme.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

#Preview {
    EditProfileView().environmentObject(AuthViewModel())
}
