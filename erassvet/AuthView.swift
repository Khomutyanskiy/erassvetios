//
//  AuthView.swift
//  erassvet
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showForgotPassword = false
    @State private var acceptedTerms = false
    @State private var showTerms = false

    private var passwordsMismatch: Bool {
        isSignUp && !confirmPassword.isEmpty && password != confirmPassword
    }

    private var isFormValid: Bool {
        guard !email.isEmpty, !password.isEmpty, acceptedTerms else { return false }
        if isSignUp {
            return !confirmPassword.isEmpty && password == confirmPassword
        }
        return true
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(8)
                            .background(AppTheme.card)
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundColor(AppTheme.accent)

                    Text(isSignUp ? "Создать аккаунт" : "Вход в аккаунт")
                        .font(.title2.bold())
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Используйте email и пароль")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                VStack(spacing: 14) {
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(AppTheme.textSecondary))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(14)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))

                    SecureField("", text: $password, prompt: Text("Пароль").foregroundColor(AppTheme.textSecondary))
                        .textContentType(isSignUp ? .newPassword : .password)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(14)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))

                    if isSignUp {
                        SecureField("", text: $confirmPassword, prompt: Text("Подтвердите пароль").foregroundColor(AppTheme.textSecondary))
                            .textContentType(.newPassword)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(passwordsMismatch ? Color.red : AppTheme.cardBorder, lineWidth: 1)
                            )
                    }

                    if !isSignUp {
                        HStack {
                            Spacer()
                            Button {
                                showForgotPassword = true
                            } label: {
                                Text("Забыли пароль?")
                                    .font(.footnote)
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                    }
                }

                if passwordsMismatch {
                    Text("Пароли не совпадают")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        acceptedTerms.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                                .foregroundColor(acceptedTerms ? AppTheme.accent : AppTheme.textSecondary)
                                .font(.system(size: 18))

                            Text("Я принимаю условия использования")
                                .font(.footnote)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        showTerms = true
                    } label: {
                        Text("Открыть текст условий использования")
                            .font(.caption)
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.leading, 28)
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        if isSignUp {
                            await authViewModel.signUp(email: email, password: password)
                        } else {
                            await authViewModel.signIn(email: email, password: password)
                        }
                        if authViewModel.isAuthenticated {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isSignUp ? "Зарегистрироваться" : "Войти")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(AppTheme.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isFormValid || authViewModel.isLoading)

                Button {
                    withAnimation {
                        isSignUp.toggle()
                        authViewModel.errorMessage = nil
                        confirmPassword = ""
                    }
                } label: {
                    Text(isSignUp ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Зарегистрироваться")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accent)
                }

                Spacer()
            }
            .padding(24)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(email: email).environmentObject(authViewModel)
        }
        .sheet(isPresented: $showTerms) {
            TermsOfUseView()
        }
    }
}

#Preview {
    AuthView().environmentObject(AuthViewModel())
}
