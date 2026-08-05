//
//  HelpView.swift
//  erassvet
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SupportContactsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppTheme.accent)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Не удалось загрузить контакты")
                                .foregroundColor(AppTheme.textPrimary)
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    } else if viewModel.contacts.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Контакты поддержки скоро появятся здесь")
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Свяжитесь с нами")
                                    .font(.title3.bold())
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.top, 8)

                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.contacts.enumerated()), id: \.element.id) { index, contact in
                                        ContactRow(contact: contact)
                                        if index < viewModel.contacts.count - 1 {
                                            Divider().overlay(AppTheme.cardBorder)
                                        }
                                    }
                                }
                                .background(AppTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Помощь")
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
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}

private struct ContactRow: View {
    let contact: SupportContact

    var body: some View {
        Button {
            open()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(contact.tint.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: contact.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(contact.tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(contact.title)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(contact.value)
                        .font(.footnote)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(16)
        }
    }

    private func open() {
        guard let url = URL(string: contact.urlString) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

#Preview {
    HelpView()
}
