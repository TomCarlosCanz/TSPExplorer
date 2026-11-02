import SwiftUI
import MapKit

/// Settings popover: the app's language and which real cities take part.
struct SettingsView: View {
    @Bindable var model: ExplorerModel
    @Bindable private var localization = Localization.shared

    /// One-tap city counts for presenting, ending with "All".
    private var quickCounts: [Int] {
        let all = model.region.cities.count
        return [10, 20].filter { $0 < all } + [all]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("Language", "Sprache")) {
                    Picker(tr("Language", "Sprache"), selection: $localization.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section(tr("Region", "Region")) {
                    Picker(tr("Region", "Region"), selection: Binding(
                        get: { model.region },
                        set: { model.setRegion($0) }
                    )) {
                        ForEach(Region.allCases) { region in
                            Label(region.title, systemImage: region.symbol).tag(region)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Stepper(
                        value: Binding(
                            get: { model.cityCount },
                            set: { model.setCityCount($0) }
                        ),
                        in: 3...model.region.cities.count
                    ) {
                        LabeledContent(tr("Cities", "Städte"), value: "\(model.cityCount)")
                    }
                    HStack {
                        Text(tr("Quick pick", "Schnellwahl"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        ForEach(quickCounts, id: \.self) { count in
                            Button(count == model.region.cities.count ? tr("All \(count)", "Alle \(count)") : "\(count)") {
                                model.setCityCount(count)
                            }
                            .buttonStyle(.bordered)
                            .tint(count == model.cityCount ? .accentColor : .secondary)
                        }
                    }
                } footer: {
                    Text(tr("The largest cities come first. Tap a city on the map to leave it out; \(model.activeCities.count) cities are in the tour right now.",
                            "Die größten Städte kommen zuerst. Tippe eine Stadt auf der Karte an, um sie auszulassen; gerade sind \(model.activeCities.count) Städte in der Tour."))
                }

                Section(tr("Your Cities", "Eigene Städte")) {
                    ForEach(model.customCities) { city in
                        LabeledContent(city.displayName, value: city.country)
                    }
                    .onDelete { model.removeCustom(at: $0) }

                    NavigationLink {
                        CitySearchView(model: model)
                    } label: {
                        Label(tr("Add a City", "Stadt hinzufügen"), systemImage: "plus")
                    }
                }

                Section {
                    Toggle(tr("Show City Names", "Städtenamen anzeigen"), isOn: $model.showNames)
                    if !model.excluded.isEmpty {
                        Button(tr("Include All Cities", "Alle Städte einbeziehen")) { model.includeAll() }
                    }
                }
            }
            .navigationTitle(tr("Settings", "Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Finds any real place with MapKit's local search.
struct CitySearchView: View {
    let model: ExplorerModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        List {
            if isSearching && results.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            ForEach(results, id: \.self) { item in
                Button {
                    add(item)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? tr("Unknown place", "Unbekannter Ort"))
                            .foregroundStyle(.primary)
                        Text(subtitle(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if !isSearching && results.isEmpty {
                ContentUnavailableView(
                    query.count < 2 ? tr("Search for a City", "Stadt suchen") : tr("No Results", "Keine Ergebnisse"),
                    systemImage: "magnifyingglass",
                    description: Text(query.count < 2
                        ? tr("Any city in the world can join the tour.", "Jede Stadt der Welt kann Teil der Tour werden.")
                        : tr("Try a different spelling.", "Versuche eine andere Schreibweise."))
                )
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("City name", "Name der Stadt"))
        .task(id: query) {
            // Small debounce so we don't search on every keystroke.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search()
        }
        .navigationTitle(tr("Add a City", "Stadt hinzufügen"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            results = []
            return
        }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = .address
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = Array(response.mapItems.prefix(8))
        } catch {
            results = []
        }
        isSearching = false
    }

    private func subtitle(for item: MKMapItem) -> String {
        [item.placemark.administrativeArea, item.placemark.country]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func add(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let city = City(
            item.name ?? "City",
            item.placemark.country ?? "",
            coordinate.latitude,
            coordinate.longitude,
            id: "custom|\(coordinate.latitude),\(coordinate.longitude)"
        )
        model.addCustom(city)
        dismiss()
    }
}
