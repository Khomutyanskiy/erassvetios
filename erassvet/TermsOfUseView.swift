//
//  TermsOfUseView.swift
//  erassvet
//

import SwiftUI

/// Full-text sheet for `TermsOfUseContent` — opened from the checkbox link on
/// `AuthView` (before signup/login) and from Профиль → Настройки → Условия
/// использования, so the text stays reachable after the account exists too.
struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(TermsOfUseContent.text)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Условия использования")
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
    }
}

#Preview {
    TermsOfUseView()
}
