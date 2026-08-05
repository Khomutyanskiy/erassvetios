//
//  YandexMapPickerView.swift
//  erassvet
//

import SwiftUI
import WebKit

/// UIViewRepresentable wrapping a WKWebView that renders the Yandex Maps
/// JS API. Tapping the map drops a pin and reports the coordinate back
/// to SwiftUI via a WKScriptMessageHandler.
struct YandexMapWebView: UIViewRepresentable {
    @Binding var pickedCoordinate: (lat: Double, lon: Double)?
    var initialCoordinate: (lat: Double, lon: Double)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "mapPicker")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(Self.html(center: initialCoordinate), baseURL: URL(string: "https://yandex.ru"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// Default map center — п. Рассвет, Аксайский район, Ростовская область.
    static let defaultCenter: (lat: Double, lon: Double) = (47.3615, 39.8779)

    static func html(center: (lat: Double, lon: Double)?) -> String {
        let lat = center?.lat ?? defaultCenter.lat
        let lon = center?.lon ?? defaultCenter.lon
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <script src="https://api-maps.yandex.ru/2.1/?apikey=\(YandexConfig.mapsAPIKey)&lang=ru_RU" type="text/javascript"></script>
        <style>html,body,#map{width:100%;height:100%;margin:0;padding:0;}</style>
        </head>
        <body>
        <div id="map"></div>
        <script>
        ymaps.ready(init);
        var myMap, myPlacemark;
        function init(){
            myMap = new ymaps.Map("map", {
                center: [\(lat), \(lon)],
                zoom: 16,
                controls: ['zoomControl', 'geolocationControl']
            });
            myMap.events.add('click', function (e) {
                var coords = e.get('coords');
                setPlacemark(coords);
            });
            setPlacemark([\(lat), \(lon)]);
        }
        function setPlacemark(coords){
            if (myPlacemark) {
                myPlacemark.geometry.setCoordinates(coords);
            } else {
                myPlacemark = new ymaps.Placemark(coords, {}, {preset: 'islands#redDotIcon'});
                myMap.geoObjects.add(myPlacemark);
            }
            window.webkit.messageHandlers.mapPicker.postMessage({lat: coords[0], lon: coords[1]});
        }
        </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let parent: YandexMapWebView

        init(_ parent: YandexMapWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard
                message.name == "mapPicker",
                let body = message.body as? [String: Any],
                let lat = body["lat"] as? Double,
                let lon = body["lon"] as? Double
            else { return }
            DispatchQueue.main.async {
                self.parent.pickedCoordinate = (lat, lon)
            }
        }
    }
}

/// Sheet that hosts the map picker plus a confirm button and shows the
/// reverse-geocoded address for the currently selected point.
struct YandexMapPickerSheet: View {
    var initialCoordinate: (lat: Double, lon: Double)?
    var onConfirm: (_ lat: Double, _ lon: Double, _ address: YandexGeocoder.Result?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pickedCoordinate: (lat: Double, lon: Double)?
    @State private var resolvedAddress: YandexGeocoder.Result?
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                YandexMapWebView(pickedCoordinate: $pickedCoordinate, initialCoordinate: initialCoordinate)
                    .ignoresSafeArea(edges: .bottom)
                    .onChange(of: pickedCoordinate?.lat) { _ in resolveAddress() }
                    .onChange(of: pickedCoordinate?.lon) { _ in resolveAddress() }

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if isResolving {
                                ProgressView().tint(AppTheme.accent)
                            }
                            Text(isResolving ? "Определяем адрес…" : (resolvedAddress?.formattedAddress ?? "Коснитесь карты, чтобы указать точку"))
                                .font(.footnote)
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(2)
                            Spacer()
                        }

                        if let coord = pickedCoordinate {
                            Text(String(format: "%.6f, %.6f", coord.lat, coord.lon))
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))

                    Button {
                        guard let coord = pickedCoordinate else { return }
                        onConfirm(coord.lat, coord.lon, resolvedAddress)
                        dismiss()
                    } label: {
                        Text("Подтвердить точку")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(pickedCoordinate == nil ? AppTheme.accent.opacity(0.4) : AppTheme.accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(pickedCoordinate == nil)
                }
                .padding(16)
            }
            .navigationTitle("Укажите точку на карте")
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

    private func resolveAddress() {
        guard let coord = pickedCoordinate else { return }
        isResolving = true
        Task {
            let result = await YandexGeocoder.reverseGeocode(latitude: coord.lat, longitude: coord.lon)
            await MainActor.run {
                resolvedAddress = result
                isResolving = false
            }
        }
    }
}
