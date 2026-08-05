//
//  PostAdView.swift
//  erassvet
//

import SwiftUI
import FirebaseAuth
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct PostAdView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var adsViewModel = AdsViewModel()
    @StateObject private var categoriesViewModel = CategoriesViewModel()

    /// When non-nil, the form starts pre-filled with this ad and saving
    /// updates it instead of creating a new one.
    var existingAd: Ad?

    @State private var showAuth = false

    @State private var title: String
    @State private var description: String
    @State private var priceText: String
    @State private var street: String
    @State private var house: String
    @State private var apartment: String
    @State private var note: String
    @State private var coordinate: (lat: Double, lon: Double)?
    @State private var category: String
    @State private var dealType: AdDealType
    @State private var existingImageURLs: [String]
    @State private var newImages: [UIImage] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isProcessingPickedPhotos = false
    @State private var showSuccess = false
    @State private var wasSentForModeration = false
    @State private var showMapPicker = false
    @State private var adStatus: AdStatus
    @State private var isPerformingStatusAction = false
    @State private var showDeleteConfirm = false
    @State private var profileContacts = UserContacts()
    @State private var selectedContactKeys: Set<String> = []
    @State private var isLoadingProfileContacts = true
    @State private var showEditProfileForContacts = false
    @State private var adContactValue: String = ""

    /// Label used to recognize the ad-specific contact (stored as a regular
    /// custom contact in `contacts.other`) when re-loading an ad for editing.
    private static let adContactLabel = "Для этого объявления"

    init(existingAd: Ad? = nil) {
        self.existingAd = existingAd
        _adStatus = State(initialValue: existingAd?.status ?? .active)
        _title = State(initialValue: existingAd?.title ?? "")
        _description = State(initialValue: existingAd?.description ?? "")
        if let price = existingAd?.price {
            _priceText = State(initialValue: String(Int(price)))
        } else {
            _priceText = State(initialValue: "")
        }
        _street = State(initialValue: existingAd?.street ?? "")
        _house = State(initialValue: existingAd?.house ?? "")
        _apartment = State(initialValue: existingAd?.apartment ?? "")
        _note = State(initialValue: existingAd?.note ?? "")
        if let lat = existingAd?.latitude, let lon = existingAd?.longitude {
            _coordinate = State(initialValue: (lat, lon))
        } else {
            _coordinate = State(initialValue: nil)
        }
        _category = State(initialValue: existingAd?.category ?? "")
        _dealType = State(initialValue: existingAd?.dealType ?? .offer)
        _existingImageURLs = State(initialValue: existingAd?.imageURLs ?? [])
    }

    private static let maxImages = 3
    private static let maxActiveAdsPerUser = 10

    private var isEditing: Bool { existingAd != nil }

    private var totalImageCount: Int { existingImageURLs.count + newImages.count }
    private var remainingImageSlots: Int { max(0, Self.maxImages - totalImageCount) }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !category.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if authViewModel.isAuthenticated {
                    form
                } else {
                    signedOutState
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Редактировать объявление" : "Новое объявление")
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
            .sheet(isPresented: $showAuth) {
                AuthView().environmentObject(authViewModel)
            }
            .sheet(isPresented: $showMapPicker) {
                YandexMapPickerSheet(initialCoordinate: coordinate) { lat, lon, address in
                    coordinate = (lat, lon)
                    if let address {
                        if let s = address.street, street.isEmpty { street = s }
                        if let h = address.house, house.isEmpty { house = h }
                    }
                }
            }
            .alert(
                isEditing ? "Изменения сохранены" : (wasSentForModeration ? "Отправлено на модерацию" : "Объявление опубликовано"),
                isPresented: $showSuccess
            ) {
                Button("Готово") { dismiss() }
            } message: {
                if isEditing {
                    Text("Объявление обновлено.")
                } else if wasSentForModeration {
                    Text("Объявление появится на главной странице после проверки администратором.")
                } else {
                    Text("Оно уже отображается на главной странице.")
                }
            }
            .alert("Удалить объявление?", isPresented: $showDeleteConfirm) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    Task { await deleteAdConfirmed() }
                }
            } message: {
                Text("Это действие необратимо.")
            }
            .onAppear { categoriesViewModel.startListening() }
            .onDisappear { categoriesViewModel.stopListening() }
            .sheet(isPresented: $showEditProfileForContacts) {
                EditProfileView().environmentObject(authViewModel)
            }
            .onChange(of: showEditProfileForContacts) { isPresented in
                if !isPresented {
                    Task { await reloadProfileContactsAfterEdit() }
                }
            }
            .task { await loadContacts() }
            .onChange(of: photoPickerItems) { items in
                guard !items.isEmpty else { return }
                Task { await processPickedPhotos(items) }
            }
        }
    }

    private func processPickedPhotos(_ items: [PhotosPickerItem]) async {
        isProcessingPickedPhotos = true
        for item in items {
            guard remainingImageSlots > 0 else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                newImages.append(image)
            }
        }
        photoPickerItems = []
        isProcessingPickedPhotos = false
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                imagePlaceholder

                if isEditing {
                    managementSection
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Тип объявления")
                        .font(.footnote)
                        .foregroundColor(AppTheme.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(AdDealType.allCases) { type in
                            Text(type.title)
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(dealType == type ? AppTheme.accent : AppTheme.card)
                                .foregroundColor(dealType == type ? .white : AppTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(dealType == type ? Color.clear : AppTheme.cardBorder, lineWidth: 1)
                                )
                                .onTapGesture {
                                    dealType = type
                                }
                        }
                    }
                }

                fieldBlock(title: "Название") {
                    TextField("", text: $title, prompt: Text("Например, Кирпич М-150 поддон").foregroundColor(AppTheme.textSecondary))
                        .foregroundColor(AppTheme.textPrimary)
                }

                fieldBlock(title: "Категория") {
                    Menu {
                        if categoriesViewModel.categories.isEmpty {
                            Text("Категории пока не добавлены")
                        } else {
                            ForEach(categoriesViewModel.categories) { cat in
                                Button(cat.title) { category = cat.title }
                            }
                        }
                    } label: {
                        HStack {
                            if categoriesViewModel.isLoading {
                                ProgressView().tint(AppTheme.textSecondary)
                            }
                            Text(category.isEmpty ? "Выберите категорию" : category)
                                .foregroundColor(category.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(.footnote)
                        }
                    }
                }

                if dealType != .free {
                    fieldBlock(title: "Цена, ₽") {
                        TextField("", text: $priceText, prompt: Text("Оставьте пустым для «Договорная»").foregroundColor(AppTheme.textSecondary))
                            .keyboardType(.numberPad)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }

                addressSection

                contactsSection

                fieldBlock(title: "Описание") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(AppTheme.textPrimary)
                }

                if let error = adsViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                Button {
                    Task { await publish() }
                } label: {
                    HStack {
                        if adsViewModel.isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(isEditing ? "Сохранить" : "Опубликовать")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(isFormValid ? AppTheme.accent : AppTheme.accent.opacity(0.4))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isFormValid || adsViewModel.isSaving)
            }
            .padding(16)
            .padding(.bottom, 40)
        }
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Адрес")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    showMapPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                        Text(coordinate == nil ? "Указать на Яндекс.Картах" : "Точка на карте выбрана")
                        Spacer()
                        if coordinate != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "3FBF7F"))
                        }
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(14)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                }

                if let coordinate {
                    Text(String(format: "%.6f, %.6f", coordinate.lat, coordinate.lon))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                }
            }

            addressField(placeholder: "Улица", text: $street)

            HStack(spacing: 10) {
                addressField(placeholder: "Дом", text: $house)
                addressField(placeholder: "Квартира / офис", text: $apartment)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Примечание")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $note)
                        .font(.subheadline)
                        .frame(minHeight: 46, maxHeight: 46)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(AppTheme.textPrimary)

                    if note.isEmpty {
                        Text("Например: домофон не работает, звонить заранее, ориентир — синий забор")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .lineLimit(2)
                    }
                }
                .padding(10)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
            }
        }
    }

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Контакты для покупателей")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)

            Text("Отметьте, какие контакты из профиля показывать в этом объявлении. Если не открыть ни один контакт, покупатели всё равно смогут написать вам во внутреннем чате.")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary.opacity(0.8))

            if isLoadingProfileContacts {
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if profileContacts.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("В профиле нет заполненных контактов")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)

                    Button {
                        showEditProfileForContacts = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить контакты в профиле")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(profileContacts.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().overlay(AppTheme.cardBorder)
                        }
                        ContactToggleRow(
                            item: item,
                            isOn: Binding(
                                get: { selectedContactKeys.contains(item.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedContactKeys.insert(item.id)
                                    } else {
                                        selectedContactKeys.remove(item.id)
                                    }
                                }
                            )
                        )
                    }
                }
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Контакт для этого объявления")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                Text("Например, отдельный номер или ссылка, которые не хочется добавлять в профиль целиком.")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary.opacity(0.8))

                TextField("", text: $adContactValue, prompt: Text("Телефон, ссылка и т.п.").foregroundColor(AppTheme.textSecondary))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(14)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
            }
        }
    }

    private func loadContacts() async {
        profileContacts = await authViewModel.loadContacts()
        if let existingAd {
            var keys: Set<String> = []
            if !existingAd.contacts.email.isEmpty { keys.insert("email") }
            if !existingAd.contacts.phone.isEmpty { keys.insert("phone") }
            if !existingAd.contacts.telegram.isEmpty { keys.insert("telegram") }
            if !existingAd.contacts.whatsapp.isEmpty { keys.insert("whatsapp") }
            if !existingAd.contacts.max.isEmpty { keys.insert("max") }
            for adCustom in existingAd.contacts.other {
                // The ad-specific contact field lives in its own state, not
                // among the toggleable profile contacts — skip it here.
                if adCustom.label.trimmingCharacters(in: .whitespaces) == Self.adContactLabel {
                    adContactValue = adCustom.value
                    continue
                }
                let label = adCustom.label.trimmingCharacters(in: .whitespaces).lowercased()
                if let match = profileContacts.items.first(where: {
                    $0.id.hasPrefix("custom_") && $0.title.trimmingCharacters(in: .whitespaces).lowercased() == label
                }) {
                    keys.insert(match.id)
                }
            }
            selectedContactKeys = keys
        } else {
            selectedContactKeys = []
        }
        isLoadingProfileContacts = false
    }

    /// Re-loads contacts after the user edits their profile from within this
    /// form, without discarding choices they've already made. Newly added
    /// contacts stay off by default, same as the initial state.
    private func reloadProfileContactsAfterEdit() async {
        profileContacts = await authViewModel.loadContacts()
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Управление объявлением")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(adStatus == .active ? Color(hex: "3FBF7F") : AppTheme.textSecondary)
                            .frame(width: 8, height: 8)
                        Text(adStatus.title)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Spacer()
                    if isPerformingStatusAction {
                        ProgressView().tint(AppTheme.accent)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { adStatus == .active },
                            set: { _ in Task { await toggleActive() } }
                        ))
                        .labelsHidden()
                        .tint(AppTheme.accent)
                    }
                }
                .padding(14)

                Divider().overlay(AppTheme.cardBorder)

                Button {
                    Task { await reissueAd() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Перевыпустить")
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundColor(AppTheme.accent)
                    .padding(14)
                }
                .disabled(isPerformingStatusAction)

                Divider().overlay(AppTheme.cardBorder)

                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Удалить объявление")
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(14)
                }
                .disabled(isPerformingStatusAction)
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
        }
    }

    private func toggleActive() async {
        guard let existingAd else { return }
        isPerformingStatusAction = true
        let newStatus: AdStatus = adStatus == .active ? .inactive : .active
        if await adsViewModel.setStatus(adId: existingAd.id, status: newStatus) {
            adStatus = newStatus
        }
        isPerformingStatusAction = false
    }

    private func reissueAd() async {
        guard let existingAd else { return }
        isPerformingStatusAction = true
        if await adsViewModel.reissue(adId: existingAd.id) {
            adStatus = .active
        }
        isPerformingStatusAction = false
    }

    private func deleteAdConfirmed() async {
        guard let existingAd else { return }
        isPerformingStatusAction = true
        if await adsViewModel.deleteAd(adId: existingAd.id, imageURLs: existingAd.imageURLs) {
            dismiss()
        }
        isPerformingStatusAction = false
    }

    private func addressField(placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundColor(AppTheme.textSecondary))
            .foregroundColor(AppTheme.textPrimary)
            .padding(14)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var imagePlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Фото")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("\(totalImageCount)/\(Self.maxImages)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(existingImageURLs.enumerated()), id: \.offset) { index, urlString in
                        imageThumbnail {
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        AppTheme.card
                                    }
                                }
                            } else {
                                AppTheme.card
                            }
                        } onDelete: {
                            existingImageURLs.remove(at: index)
                        }
                    }

                    ForEach(Array(newImages.enumerated()), id: \.offset) { index, uiImage in
                        imageThumbnail {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } onDelete: {
                            newImages.remove(at: index)
                        }
                    }

                    if remainingImageSlots > 0 {
                        PhotosPicker(
                            selection: $photoPickerItems,
                            maxSelectionCount: remainingImageSlots,
                            matching: .images
                        ) {
                            VStack(spacing: 6) {
                                if isProcessingPickedPhotos {
                                    ProgressView().tint(AppTheme.textSecondary)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text("Добавить")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .frame(width: 96, height: 96)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(AppTheme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [6]))
                            )
                        }
                        .disabled(isProcessingPickedPhotos)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func imageThumbnail<Content: View>(@ViewBuilder content: () -> Content, onDelete: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)

            content()
                .padding(14)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
        }
    }

    private var signedOutState: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle")
                .font(.system(size: 56))
                .foregroundColor(AppTheme.textSecondary)
            Text("Нужна авторизация")
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)
            Text("Войдите, чтобы разместить объявление")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            Button {
                showAuth = true
            } label: {
                Text("Войти")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func publish() async {
        guard let user = authViewModel.user else { return }

        var initialStatus: AdStatus = .active
        if existingAd == nil {
            let activeCount = await adsViewModel.activeAdCount(for: user.uid)
            guard activeCount < Self.maxActiveAdsPerUser else {
                adsViewModel.errorMessage = "Достигнут лимит: не более \(Self.maxActiveAdsPerUser) активных объявлений. Снимите или удалите одно из текущих, чтобы опубликовать новое."
                return
            }
            if await adsViewModel.isModerationEnabled() {
                initialStatus = .pending
            }
        }
        wasSentForModeration = initialStatus == .pending

        let price = dealType == .free ? nil : Double(priceText.replacingOccurrences(of: " ", with: ""))
        var contactsToSave = profileContacts.filtered(keys: selectedContactKeys)
        let trimmedAdContact = adContactValue.trimmingCharacters(in: .whitespaces)
        if !trimmedAdContact.isEmpty {
            contactsToSave.other.append(CustomContact(label: Self.adContactLabel, value: trimmedAdContact))
        }
        let success: Bool
        if let existingAd {
            success = await adsViewModel.updateAd(
                id: existingAd.id,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                category: category,
                price: price,
                street: street.trimmingCharacters(in: .whitespaces),
                house: house.trimmingCharacters(in: .whitespaces),
                apartment: apartment.trimmingCharacters(in: .whitespaces),
                note: note.trimmingCharacters(in: .whitespaces),
                latitude: coordinate?.lat,
                longitude: coordinate?.lon,
                dealType: dealType,
                contacts: contactsToSave,
                sellerId: existingAd.sellerId,
                keptImageURLs: existingImageURLs,
                newImages: newImages
            )
        } else {
            success = await adsViewModel.createAd(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                category: category,
                price: price,
                street: street.trimmingCharacters(in: .whitespaces),
                house: house.trimmingCharacters(in: .whitespaces),
                apartment: apartment.trimmingCharacters(in: .whitespaces),
                note: note.trimmingCharacters(in: .whitespaces),
                latitude: coordinate?.lat,
                longitude: coordinate?.lon,
                sellerId: user.uid,
                sellerName: user.displayName?.isEmpty == false ? user.displayName! : (user.email ?? "Пользователь"),
                sellerPhotoURL: user.photoURL?.absoluteString,
                dealType: dealType,
                contacts: contactsToSave,
                newImages: newImages,
                initialStatus: initialStatus
            )
        }
        if success {
            if let existingAd {
                let removedURLs = Set(existingAd.imageURLs).subtracting(existingImageURLs)
                for url in removedURLs {
                    await StorageService.deleteImage(url: url)
                }
            }
            showSuccess = true
        }
    }
}

private struct ContactToggleRow: View {
    let item: ContactItem
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(item.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text(item.value)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
        .padding(14)
    }
}

#Preview {
    PostAdView().environmentObject(AuthViewModel())
}
