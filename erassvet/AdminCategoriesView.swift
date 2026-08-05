//
//  AdminCategoriesView.swift
//  erassvet
//

import SwiftUI

/// Admin-only screen for managing ad categories ("categories" collection).
/// Reached from AdminPanelView. Add/delete are enforced admin-only by
/// Firestore security rules as well.
struct AdminCategoriesView: View {
    @StateObject private var categoriesViewModel = CategoriesViewModel()
    @State private var newCategoryTitle = ""
    @State private var categoryPendingDelete: AppCategory?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Эти категории будут доступны при создании объявления и в фильтрах ленты.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 10) {
                    TextField("", text: $newCategoryTitle, prompt: Text("Новая категория").foregroundColor(AppTheme.textSecondary))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(14)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))

                    Button {
                        Task {
                            let title = newCategoryTitle
                            if await categoriesViewModel.addCategory(title: title) {
                                newCategoryTitle = ""
                            }
                        }
                    } label: {
                        if categoriesViewModel.isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.headline)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .background(
                        newCategoryTitle.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AppTheme.accent.opacity(0.4)
                            : AppTheme.accent
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(newCategoryTitle.trimmingCharacters(in: .whitespaces).isEmpty || categoriesViewModel.isSaving)
                }

                if let error = categoriesViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                if categoriesViewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else if categoriesViewModel.categories.isEmpty {
                    Text("Категорий пока нет — добавьте первую выше.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(categoriesViewModel.categories.enumerated()), id: \.element.id) { index, category in
                            if index > 0 {
                                Divider().overlay(AppTheme.cardBorder)
                            }
                            HStack {
                                Text(category.title)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Button {
                                    categoryPendingDelete = category
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(14)
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
        .navigationTitle("Категории объявлений")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { categoriesViewModel.startListening() }
        .onDisappear { categoriesViewModel.stopListening() }
        .alert("Удалить категорию?", isPresented: Binding(
            get: { categoryPendingDelete != nil },
            set: { if !$0 { categoryPendingDelete = nil } }
        )) {
            Button("Отмена", role: .cancel) { categoryPendingDelete = nil }
            Button("Удалить", role: .destructive) {
                if let category = categoryPendingDelete {
                    Task { _ = await categoriesViewModel.deleteCategory(id: category.id) }
                }
                categoryPendingDelete = nil
            }
        } message: {
            Text("Объявления в этой категории не удаляются, но категория пропадёт из выбора.")
        }
    }
}

#Preview {
    NavigationStack {
        AdminCategoriesView()
    }
}
