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
    /// A second trailing icon, rendered just before `trailingIcon` (e.g.
    /// Feed's favorites shortcut sitting next to the search icon). Defaults
    /// to nil so existing single-icon call sites are unaffected.
    var secondaryTrailingIcon: String? = nil
    var secondaryTrailingAction: (() -> Void)? = nil
    /// A third trailing icon, rendered before `secondaryTrailingIcon` (e.g.
    /// Feed's subscriptions shortcut sitting left of favorites/search).
    /// Defaults to nil so existing call sites are unaffected.
    var tertiaryTrailingIcon: String? = nil
    var tertiaryTrailingAction: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            if trailingIcon != nil || secondaryTrailingIcon != nil || tertiaryTrailingIcon != nil {
                HStack(spacing: 4) {
                    Spacer()

                    if let tertiaryTrailingIcon {
                        Button {
                            tertiaryTrailingAction?()
                        } label: {
                            Image(systemName: tertiaryTrailingIcon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(width: 32, height: 32)
                        }
                    }

                    if let secondaryTrailingIcon {
                        Button {
                            secondaryTrailingAction?()
                        } label: {
                            Image(systemName: secondaryTrailingIcon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(width: 32, height: 32)
                        }
                    }

                    if let trailingIcon {
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
}
