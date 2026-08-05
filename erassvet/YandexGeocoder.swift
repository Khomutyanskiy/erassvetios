//
//  YandexGeocoder.swift
//  erassvet
//

import Foundation

enum YandexGeocoder {
    struct Result {
        let latitude: Double
        let longitude: Double
        let formattedAddress: String
        let street: String?
        let house: String?
    }

    /// Reverse geocoding: coordinates -> address.
    static func reverseGeocode(latitude: Double, longitude: Double) async -> Result? {
        var components = URLComponents(string: "https://geocode-maps.yandex.ru/1.x/")!
        components.queryItems = [
            URLQueryItem(name: "apikey", value: YandexConfig.geocoderAPIKey),
            URLQueryItem(name: "geocode", value: "\(longitude),\(latitude)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "lang", value: "ru_RU"),
            URLQueryItem(name: "results", value: "1")
        ]
        guard let url = components.url else { return nil }
        return await fetch(url: url, fallbackLatitude: latitude, fallbackLongitude: longitude)
    }

    /// Forward geocoding: address text -> coordinates.
    static func geocode(address: String) async -> Result? {
        var components = URLComponents(string: "https://geocode-maps.yandex.ru/1.x/")!
        components.queryItems = [
            URLQueryItem(name: "apikey", value: YandexConfig.geocoderAPIKey),
            URLQueryItem(name: "geocode", value: address),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "lang", value: "ru_RU"),
            URLQueryItem(name: "results", value: "1")
        ]
        guard let url = components.url else { return nil }
        return await fetch(url: url, fallbackLatitude: nil, fallbackLongitude: nil)
    }

    private static func fetch(url: URL, fallbackLatitude: Double?, fallbackLongitude: Double?) async -> Result? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let response = json["response"] as? [String: Any],
                let collection = response["GeoObjectCollection"] as? [String: Any],
                let members = collection["featureMember"] as? [[String: Any]],
                let first = members.first,
                let geoObject = first["GeoObject"] as? [String: Any]
            else { return nil }

            let metaContainer = geoObject["metaDataProperty"] as? [String: Any]
            let meta = metaContainer?["GeocoderMetaData"] as? [String: Any]
            let text = meta?["text"] as? String ?? ""

            var street: String?
            var house: String?
            if let address = meta?["Address"] as? [String: Any],
               let comps = address["Components"] as? [[String: Any]] {
                for comp in comps {
                    guard let kind = comp["kind"] as? String, let name = comp["name"] as? String else { continue }
                    if kind == "street" { street = name }
                    if kind == "house" { house = name }
                }
            }

            var latitude = fallbackLatitude
            var longitude = fallbackLongitude
            if let point = geoObject["Point"] as? [String: Any],
               let posString = point["pos"] as? String {
                let parts = posString.split(separator: " ")
                if parts.count == 2, let lon = Double(parts[0]), let lat = Double(parts[1]) {
                    longitude = lon
                    latitude = lat
                }
            }

            guard let lat = latitude, let lon = longitude else { return nil }

            return Result(
                latitude: lat,
                longitude: lon,
                formattedAddress: text,
                street: street,
                house: house
            )
        } catch {
            return nil
        }
    }
}
