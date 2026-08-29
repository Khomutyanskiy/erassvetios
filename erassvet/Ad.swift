//
//  Ad.swift
//  erassvet
//

import Foundation
import FirebaseFirestore

enum AdStatus: String {
    case active
    case inactive
    /// Awaiting admin review — only visible to its owner and admins, hidden
    /// from the public feed. Only assigned when moderation is turned on in
    /// the admin panel ("app_config/moderation.enabled").
    case pending
    /// Rejected by an admin during moderation — stays visible to the owner
    /// (with the reason implied by the badge) but never reaches the feed.
    case rejected

    var title: String {
        switch self {
        case .active: return "Активно"
        case .inactive: return "Неактивно"
        case .pending: return "На модерации"
        case .rejected: return "Отклонено"
        }
    }
}

/// The kind of listing — offering something, looking for something, or
/// giving it away for free. Shown as a badge on the card/detail screen and
/// filterable in the feed alongside category.
enum AdDealType: String, CaseIterable, Identifiable {
    case offer = "Предлагаю"
    case request = "Требуется"
    case free = "Даром"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// Real Firestore-backed listing ("объявление").
/// Stored in the "ads" collection. `imageURLs` holds up to 5 photo URLs
/// uploaded to Firebase Storage.
struct Ad: Identifiable, Hashable {
    static func == (lhs: Ad, rhs: Ad) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let title: String
    let description: String
    let category: String
    let price: Double?
    let sellerId: String
    let sellerName: String
    let sellerPhotoURL: String?
    let imageURLs: [String]
    let status: AdStatus
    let dealType: AdDealType
    let views: Int
    let createdAt: Date?

    // Address
    let street: String
    let house: String
    let apartment: String
    let note: String
    let latitude: Double?
    let longitude: Double?

    /// Contacts the seller chose to show on this specific ad (a snapshot
    /// of their profile contacts at the time they were selected).
    let contacts: UserContacts

    /// An optional contact person specific to this ad (e.g. a colleague or
    /// a separate number the seller doesn't want on their whole profile).
    /// When `adContactValue` is filled in, the detail screen shows only this
    /// contact and hides both the seller card and the profile contacts.
    let adContactName: String
    let adContactValue: String

    /// Legacy storage key — before `adContactName`/`adContactValue` existed,
    /// the per-ad contact was kept as a custom contact under this label.
    /// Still read (and lifted out of `contacts`) so older ads render right.
    static let legacyAdContactLabel = "Для этого объявления"

    var hasAdContact: Bool {
        !adContactValue.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Displayable form of the ad-specific contact, reusing the same tappable
    /// row model as the profile contacts.
    var adContactItem: ContactItem? {
        let trimmedValue = adContactValue.trimmingCharacters(in: .whitespaces)
        guard !trimmedValue.isEmpty else { return nil }
        let trimmedName = adContactName.trimmingCharacters(in: .whitespaces)
        return ContactItem(
            id: "ad_contact",
            icon: "person.crop.circle.fill",
            tint: AppTheme.accent,
            title: trimmedName.isEmpty ? "Контакт по объявлению" : trimmedName,
            value: trimmedValue,
            urlString: Ad.contactURLString(for: trimmedValue)
        )
    }

    /// Best-effort tappable link for a free-form contact: a phone number
    /// becomes a `tel:` link, an email a `mailto:` link, anything already
    /// URL-shaped is used as-is.
    private static func contactURLString(for value: String) -> String {
        if value.contains("@"), !value.contains(" "), !value.lowercased().hasPrefix("http") {
            return "mailto:\(value)"
        }
        if value.lowercased().hasPrefix("http") || value.lowercased().hasPrefix("tg:") {
            return value
        }
        let digits = value.filter { $0.isNumber || $0 == "+" }
        if digits.filter(\.isNumber).count >= 6 {
            return "tel:\(digits)"
        }
        return value
    }

    var priceText: String {
        if dealType == .free { return "Даром" }
        guard let price else { return "Договорная" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
        return "\(formatted) ₽"
    }

    var hasImage: Bool { !imageURLs.isEmpty }

    /// Seller name shown to buyers. `sellerName` is either the seller's
    /// display name or (if none was set) their email — never show the full
    /// email, only the part before "@".
    var sellerDisplayName: String {
        if let atIndex = sellerName.firstIndex(of: "@") {
            return String(sellerName[..<atIndex])
        }
        return sellerName
    }

    var hasCoordinates: Bool { latitude != nil && longitude != nil }

    /// Human-readable address built from street/house/apartment.
    /// Falls back to an empty string if nothing was filled in.
    var addressText: String {
        var parts: [String] = []
        if !street.isEmpty {
            var streetPart = street
            if !house.isEmpty { streetPart += ", \(house)" }
            parts.append(streetPart)
        } else if !house.isEmpty {
            parts.append(house)
        }
        if !apartment.isEmpty {
            parts.append("кв. \(apartment)")
        }
        return parts.joined(separator: ", ")
    }

    /// "1 просмотр" / "3 просмотра" / "5 просмотров" — correct Russian
    /// plural form for `views`, shared by AdDetailView and "Мои объявления".
    var viewsText: String {
        let rem100 = views % 100
        let rem10 = views % 10
        let word: String
        if rem100 >= 11 && rem100 <= 14 {
            word = "просмотров"
        } else {
            switch rem10 {
            case 1: word = "просмотр"
            case 2, 3, 4: word = "просмотра"
            default: word = "просмотров"
            }
        }
        return "\(views) \(word)"
    }

    var timeAgoText: String {
        guard let createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    init?(id: String, data: [String: Any]) {
        guard
            let title = data["title"] as? String,
            let category = data["category"] as? String,
            let sellerId = data["sellerId"] as? String
        else { return nil }

        self.id = id
        self.title = title
        self.description = data["description"] as? String ?? ""
        self.category = category
        self.price = data["price"] as? Double
        self.sellerId = sellerId
        self.sellerName = data["sellerName"] as? String ?? "Пользователь"
        self.sellerPhotoURL = data["sellerPhotoURL"] as? String
        self.imageURLs = data["imageURLs"] as? [String] ?? []
        self.status = AdStatus(rawValue: data["status"] as? String ?? "") ?? .active
        self.dealType = AdDealType(rawValue: data["dealType"] as? String ?? "") ?? .offer
        self.views = data["views"] as? Int ?? 0
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }

        self.street = data["street"] as? String ?? ""
        self.house = data["house"] as? String ?? ""
        self.apartment = data["apartment"] as? String ?? ""
        self.note = data["note"] as? String ?? ""
        self.latitude = data["latitude"] as? Double
        self.longitude = data["longitude"] as? Double

        var parsedContacts = UserContacts.from(data["contacts"] as? [String: Any], fallbackEmail: "")
        var contactName = data["adContactName"] as? String ?? ""
        var contactValue = data["adContactValue"] as? String ?? ""

        // Backward compatibility: ads created before these fields existed
        // stored the per-ad contact as a custom contact with a sentinel
        // label. Lift it out so it isn't rendered twice.
        if contactValue.isEmpty,
           let legacyIndex = parsedContacts.other.firstIndex(where: { $0.label == Ad.legacyAdContactLabel }) {
            contactValue = parsedContacts.other[legacyIndex].value
            parsedContacts.other.remove(at: legacyIndex)
            if contactName.isEmpty {
                contactName = data["sellerName"] as? String ?? ""
            }
        }

        self.contacts = parsedContacts
        self.adContactName = contactName
        self.adContactValue = contactValue
    }

    /// Fields for creating a new ad document. `imageURLs` holds up to 5
    /// already-uploaded Storage download URLs.
    static func newAdData(
        title: String,
        description: String,
        category: String,
        price: Double?,
        street: String,
        house: String,
        apartment: String,
        note: String,
        latitude: Double?,
        longitude: Double?,
        sellerId: String,
        sellerName: String,
        sellerPhotoURL: String?,
        dealType: AdDealType,
        contacts: UserContacts,
        adContactName: String,
        adContactValue: String,
        imageURLs: [String],
        initialStatus: AdStatus = .active
    ) -> [String: Any] {
        [
            "title": title,
            "description": description,
            "category": category,
            "price": price as Any,
            "street": street,
            "house": house,
            "apartment": apartment,
            "note": note,
            "latitude": latitude as Any,
            "longitude": longitude as Any,
            "sellerId": sellerId,
            "sellerName": sellerName,
            "sellerPhotoURL": sellerPhotoURL as Any,
            "imageURLs": imageURLs,
            "status": initialStatus.rawValue,
            "dealType": dealType.rawValue,
            "views": 0,
            "contacts": contacts.toDictionary(),
            "adContactName": adContactName,
            "adContactValue": adContactValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }

    /// Fields for updating an existing ad's editable content (status/views/
    /// createdAt/sellerId are left untouched by this update).
    static func updateData(
        title: String,
        description: String,
        category: String,
        price: Double?,
        street: String,
        house: String,
        apartment: String,
        note: String,
        latitude: Double?,
        longitude: Double?,
        dealType: AdDealType,
        contacts: UserContacts,
        adContactName: String,
        adContactValue: String,
        imageURLs: [String]
    ) -> [String: Any] {
        [
            "title": title,
            "description": description,
            "category": category,
            "price": price as Any,
            "street": street,
            "house": house,
            "apartment": apartment,
            "note": note,
            "latitude": latitude as Any,
            "longitude": longitude as Any,
            "dealType": dealType.rawValue,
            "contacts": contacts.toDictionary(),
            "adContactName": adContactName,
            "adContactValue": adContactValue,
            "imageURLs": imageURLs
        ]
    }
}
