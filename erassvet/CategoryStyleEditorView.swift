//
//  CategoryStyleEditorView.swift
//  erassvet
//

import SwiftUI

/// Sheet for picking a category's chip color, opened from
/// `AdminCategoriesView`. Saves straight to the category's Firestore doc via
/// `CategoriesViewModel.updateStyle` — the color is an optional override,
/// clearing back to the automatic hash-based color when unset.
struct CategoryStyleEditorView: View {
    let category: AppCategory
    @ObservedObject var categoriesViewModel: CategoriesViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedColor: Color
    @State private var clearedColor = false

    @MainActor
    init(category: AppCategory, categoriesViewModel: CategoriesViewModel) {
        self.category = category
        self.categoriesViewModel = categoriesViewModel
        _selectedColor = State(initialValue: category.colorHex.map { Color(hex: $0) } ?? AppTheme.colorForCategory(category.title))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    previewBlock
                    colorBlock

                    if let error = categoriesViewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    saveButton
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Цвет категории")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var previewBlock: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(selectedColor)
                .frame(width: 40, height: 40)
            Text(category.title)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var colorBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Цвет")
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.textPrimary)

            ColorPicker("Выбрать цвет", selection: $selectedColor, supportsOpacity: false)
                .padding(14)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                .foregroundColor(AppTheme.textPrimary)

            if category.colorHex != nil {
                Button("Сбросить на автоматический цвет") {
                    selectedColor = AppTheme.colorForCategory(category.title)
                    clearedColor = true
                }
                .font(.footnote)
                .foregroundColor(AppTheme.accent)
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                let hex = clearedColor ? nil : selectedColor.toHex()
                let success = await categoriesViewModel.updateStyle(id: category.id, colorHex: hex)
                if success { dismiss() }
            }
        } label: {
            if categoriesViewModel.isSaving {
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
        .disabled(categoriesViewModel.isSaving)
    }
}
