//
//  ForgotPasswordView.swift
//  erassvet
//

import SwiftUI

/// Sends a Firebase Auth password-reset email. Reachable from AuthView's
/// "Забыли пароль?" link on the sign-in screen.
struct ForgotPasswordView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State var email: String
    @State private var isSending = false
    @State private var sentTo: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.16))
                                .frame(width: 64, height: 64)
                            Image(systemName: "envelope.badge")
                                .font(.system(size: 26))
                                .foregroundColor(AppTheme.accent)
                        }

                        Text("Восстановление пароля")
                            .font(.title3.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Введите email, указанный при регистрации — пришлём ссылку для сброса пароля.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 8)

                    if let sentTo {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "3FBF7F"))
                            Text("Письмо отправлено на \(sentTo)")
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                            Text("Перейдите по ссылке из письма, чтобы задать новый пароль. Проверьте папку «Спам», если письмо не пришло в течение пары минут.")
                                .font(.footnote)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))

                        Button {
                            dismiss()
                        } label: {
                            Text("Готово")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(AppTheme.accent)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        TextField("", text: $email, prompt: Text("Email").foregroundColor(AppTheme.textSecondary))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task { await send() }
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Отправить письмо")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(AppTheme.accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isValidEmail || isSending)
                    }

                    Spacer()
                }
                .padding(24)
            }
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
            .onAppear { authViewModel.errorMessage = nil }
        }
    }

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func send() async {
        isSending = true
        await authViewModel.resetPassword(email: email.trimmingCharacters(in: .whitespaces))
        isSending = false
        if authViewModel.errorMessage == nil {
            sentTo = email.trimmingCharacters(in: .whitespaces)
        }
    }
}

#Preview {
    ForgotPasswordView(email: "").environmentObject(AuthViewModel())
}
