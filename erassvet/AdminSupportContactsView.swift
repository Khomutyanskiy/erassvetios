//
//  AdminSupportContactsView.swift
//  erassvet
//

import SwiftUI

/// Admin-only screen for managing the contacts shown on the public Помощь
/// screen ("support_contacts" collection). Reached from AdminPanelView.
struct AdminSupportContactsView: View {
    @StateObject private var viewModel = AdminSupportContactsViewModel()
    @State private var isAddingNew = false
    @State private var editingContact: SupportContact?
    @State private var contactPendingDelete: SupportContact?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Эти контакты отображаются пользователям на странице «Помощь».")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                Button {
                    isAddingNew = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Добавить контакт")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else if viewModel.contacts.isEmpty {
                    Text("Контактов пока нет — добавьте первый выше.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.contacts.enumerated()), id: \.element.id) { index, contact in
                            if index > 0 {
                                Divider().overlay(AppTheme.cardBorder)
                            }
                            ContactManageRow(
                                contact: contact,
                                canMoveUp: index > 0,
                                canMoveDown: index < viewModel.contacts.count - 1,
                                onEdit: { editingContact = contact },
                                onDelete: { contactPendingDelete = contact },
                                onMoveUp: { Task { await viewModel.move(contact, direction: -1) } },
                                onMoveDown: { Task { await viewModel.move(contact, direction: 1) } }
                            )
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
        .navigationTitle("Контакты поддержки")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .sheet(isPresented: $isAddingNew) {
            SupportContactFormView(existing: nil, viewModel: viewModel)
        }
        .sheet(item: $editingContact) { contact in
            SupportContactFormView(existing: contact, viewModel: viewModel)
        }
        .alert("Удалить контакт?", isPresented: Binding(
            get: { contactPendingDelete != nil },
            set: { if !$0 { contactPendingDelete = nil } }
        )) {
            Button("Отмена", role: .cancel) { contactPendingDelete = nil }
            Button("Удалить", role: .destructive) {
                if let contact = contactPendingDelete {
                    Task { _ = await viewModel.deleteContact(id: contact.id) }
                }
                contactPendingDelete = nil
            }
        } message: {
            Text("Контакт пропадёт со страницы «Помощь».")
        }
    }
}

private struct ContactManageRow: View {
    let contact: SupportContact
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(contact.tint.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: contact.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(contact.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.title)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(contact.value)
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundColor(canMoveUp ? AppTheme.textSecondary : AppTheme.textSecondary.opacity(0.3))
                }
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(canMoveDown ? AppTheme.textSecondary : AppTheme.textSecondary.opacity(0.3))
                }
                .disabled(!canMoveDown)
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(AppTheme.accent)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

/// Add/edit form for a single support contact. `url` is optional — when left
/// blank, a sensible default (mailto:/tel:/wa.me/t.me link) is derived from
/// `type` + `value` the same way HelpView already does for existing contacts.
private struct SupportContactFormView: View {
    let existing: SupportContact?
    @ObservedObject var viewModel: AdminSupportContactsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var type: String
    @State private var title: String
    @State private var value: String
    @State private var url: String

    private static let types: [(key: String, label: String)] = [
        ("email", "Email"),
        ("telegram", "Telegram"),
        ("whatsapp", "WhatsApp"),
        ("max", "MAX"),
        ("phone", "Телефон"),
        ("other", "Другое")
    ]

    init(existing: SupportContact?, viewModel: AdminSupportContactsViewModel) {
        self.existing = existing
        self.viewModel = viewModel
        _type = State(initialValue: existing?.type ?? "email")
        _title = State(initialValue: existing?.title ?? "")
        _value = State(initialValue: existing?.value ?? "")
        _url = State(initialValue: existing.flatMap { $0.urlString } ?? "")
    }

    private var isEditing: Bool { existing != nil }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    fieldBlock(title: "Тип") {
                        Menu {
                            ForEach(Self.types, id: \.key) { option in
                                Button(option.label) { type = option.key }
                            }
                        } label: {
                            HStack {
                                Text(Self.types.first(where: { $0.key == type })?.label ?? type)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                        }
                    }

                    fieldBlock(title: "Заголовок") {
                        TextField("", text: $title, prompt: Text("Например, Email поддержки").foregroundColor(AppTheme.textSecondary))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    fieldBlock(title: "Значение") {
                        TextField("", text: $value, prompt: Text("support@erassvet.ru").foregroundColor(AppTheme.textSecondary))
                            .autocapitalization(.none)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    fieldBlock(title: "Ссылка (необязательно)") {
                        TextField("", text: $url, prompt: Text("Определится автоматически, если пусто").foregroundColor(AppTheme.textSecondary))
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(isEditing ? "Сохранить" : "Добавить")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(isFormValid ? AppTheme.accent : AppTheme.accent.opacity(0.4))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!isFormValid || viewModel.isSaving)
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Редактировать контакт" : "Новый контакт")
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
            .onAppear { viewModel.errorMessage = nil }
        }
    }

    @ViewBuilder
    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
            content()
        }
    }

    private func save() async {
        let success: Bool
        if let existing {
            success = await viewModel.updateContact(id: existing.id, type: type, title: title, value: value, url: url)
        } else {
            success = await viewModel.addContact(type: type, title: title, value: value, url: url)
        }
        if success {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AdminSupportContactsView()
    }
}
