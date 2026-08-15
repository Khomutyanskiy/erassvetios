//
//  DeleteAccountView.swift
//  erassvet
//

import SwiftUI

/// Confirmation screen for permanently deleting the signed-in account.
/// Requires the current password (Firebase mandates a recent sign-in
/// before it allows deleting the Auth account) plus an explicit final
/// alert, so this can't be triggered by an accidental tap.
struct DeleteAccountView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isDeleting = false
    @State private var showFinalConfirm = false

    private let danger = Color(hex: "E8352B")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(danger.opacity(0.16))
                                .frame(width: 64, height: 64)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(danger)
                        }

                        Text("Это действие необратимо")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("При удалении аккаунта будут безвозвратно удалены:")
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        bulletRow("Профиль, аватар и контакты")
                        bulletRow("Все ваши объявления и фотографии")
                        bulletRow("Избранное")
                        bulletRow("Переписки в чатах")
                    }
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Подтвердите пароль")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)

                        SecureField("", text: $password, prompt: Text("Пароль").foregroundColor(AppTheme.textSecondary))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(danger)
                    }

                    Button {
                        showFinalConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            if isDeleting {
                                ProgressView().tint(.white)
                            }
                            Text("Удалить аккаунт навсегда")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(danger)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(password.isEmpty || isDeleting)
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Удаление аккаунта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .disabled(isDeleting)
                }
            }
            .alert("Удалить аккаунт безвозвратно?", isPresented: $showFinalConfirm) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    Task { await performDelete() }
                }
            } message: {
                Text("Это действие нельзя отменить.")
            }
        }
        .interactiveDismissDisabled(isDeleting)
        .onAppear { authViewModel.errorMessage = nil }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(AppTheme.textSecondary)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    private func performDelete() async {
        isDeleting = true
        let success = await authViewModel.deleteAccount(password: password)
        isDeleting = false
        if success {
            dismiss()
        }
    }
}

#Preview {
    DeleteAccountView().environmentObject(AuthViewModel())
}
