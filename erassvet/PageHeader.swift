//
//  PageHeader.swift
//  erassvet
//

import SwiftUI

/// Consistent bold title shown at the very top of each of the app's four
/// main tab screens (Лента, Чаты, Избранное, Профиль). Rendered inline in
/// the content rather than as a system navigation bar title so it looks
/// the same whether the screen scrolls or not.
struct PageHeader: View {
    let title: String
    /// Optional SF Symbol shown at the trailing edge (e.g. a search toggle).
    /// Existing call sites are unaffected since this defaults to nil.
    var trailingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            if let trailingIcon {
                HStack {
                    Spacer()
                    Button {
                        trailingAction?()
                    } label: {
                        Image(systemName: trailingIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
    }
}
