import SwiftUI
import MapKit

/// The shortest-path tab: a road network on the map and a card that plays back
/// Dijkstra's algorithm between two cities.
struct ShortestPathView: View {
    @State private var model: ShortestPathModel

    init(explorer: ExplorerModel) {
        _model = State(initialValue: ShortestPathModel(explorer: explorer))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ShortestPathMap(model: model)
                .ignoresSafeArea()

            ShortestPathPanel(model: model)
                .frame(maxWidth: 780)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        // The cities and language are changed in Settings, possibly while on the other tab.
        .onAppear { model.sync() }
        .onChange(of: model.explorer.visibleCities.map(\.id)) { model.sync() }
        .onChange(of: model.cities.map(\.id)) { model.sync() }
        .onChange(of: Localization.shared.language) { model.sync() }
    }
}

// MARK: - Map

private struct RoadSegment: Identifiable {
    let id: Int
    let points: [CLLocationCoordinate2D]
}

struct ShortestPathMap: View {
    @Bindable var model: ShortestPathModel

    var body: some View {
        let cities = model.cities
        let step = model.currentStep
        let indexByID = Dictionary(cities.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let pathEdges = zip(step?.path ?? [], (step?.path ?? []).dropFirst()).map { Edge($0, $1) }

        let roads = segments(model.network?.edges ?? [], in: cities)
        let tree = segments(step?.tree ?? [], in: cities)
        let rejected = segments(step?.rejected ?? [], in: cities)
        let improved = segments(step?.improved ?? [], in: cities)
        let path = segments(pathEdges, in: cities)

        Map(position: $model.cameraPosition) {
            ForEach(roads) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.ghost.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            ForEach(tree) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.tour.opacity(0.4), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }

            ForEach(rejected) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.removed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [5, 6]))
            }

            ForEach(improved) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.candidate, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }

            ForEach(path) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.tour, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }

            ForEach(model.explorer.visibleCities) { city in
                let index = indexByID[city.id]
                Annotation(city.displayName, coordinate: city.coordinate, anchor: .center) {
                    PathCityDot(
                        role: role(for: index, step: step),
                        marker: marker(for: city),
                        distance: index.flatMap { step?.distances[$0] }
                    )
                    .onTapGesture { if index != nil { model.tap(city) } }
                }
                .annotationTitles(model.explorer.showNames ? .automatic : .hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    private func segments(_ edges: [Edge], in cities: [City]) -> [RoadSegment] {
        edges.enumerated().compactMap { index, edge in
            guard cities.indices.contains(edge.a), cities.indices.contains(edge.b) else { return nil }
            return RoadSegment(id: index, points: [cities[edge.a].coordinate, cities[edge.b].coordinate])
        }
    }

    private func role(for index: Int?, step: DijkstraStep?) -> PathCityDot.Role {
        guard let index else { return .inactive }
        guard let step else { return .unreached }
        if step.current == index { return .current }
        if step.settled.contains(index) { return .settled }
        return step.distances[index] == nil ? .unreached : .reached
    }

    private func marker(for city: City) -> String? {
        if city.id == model.startID { return "figure.walk" }
        if city.id == model.goalID { return "flag.fill" }
        return nil
    }
}

/// A city marker showing how far Dijkstra has got with it, plus its tentative distance.
struct PathCityDot: View {
    enum Role { case inactive, unreached, reached, settled, current }

    let role: Role
    /// SF Symbol for the start or goal.
    let marker: String?
    let distance: Double?

    private var size: CGFloat {
        if marker != nil { return 28 }
        switch role {
        case .inactive: return 10
        case .unreached, .reached, .settled: return 14
        case .current: return 20
        }
    }

    private var fill: Color {
        switch role {
        case .inactive: return Color(.systemGray4)
        case .unreached, .reached: return .white
        case .settled: return Palette.tour
        case .current: return Palette.candidate
        }
    }

    private var ring: Color {
        switch role {
        case .inactive, .unreached: return Color(.systemGray)
        case .reached: return Palette.candidate
        case .settled, .current: return .white
        }
    }

    var body: some View {
        Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(ring, lineWidth: role == .inactive ? 1.5 : 3))
            .overlay {
                if let marker {
                    Image(systemName: marker)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(role == .settled || role == .current ? .white : Palette.tour)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .overlay(alignment: .top) {
                if let distance {
                    Text(distance.km)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: Capsule())
                        .fixedSize()
                        .offset(y: -22)
                }
            }
            .padding(8)
            .contentShape(Circle())
            .animation(.snappy(duration: 0.25), value: role)
    }
}

// MARK: - Card

struct ShortestPathPanel: View {
    @Bindable var model: ShortestPathModel
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            endpoints
            if let step = model.currentStep {
                content(for: step)
            } else {
                hint
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Shortest Path", "Kürzester Weg"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(tr("Dijkstra's Algorithm", "Dijkstra-Algorithmus"))
                    .font(.title.weight(.bold))
            }
            Spacer()
            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title2)
            }
            .accessibilityLabel(tr("How It Works", "So funktioniert's"))
            .popover(isPresented: $showInfo) {
                DijkstraInfoView()
                    .frame(width: 400, height: 600)
            }
        }
    }

    // MARK: Start and goal

    private var endpoints: some View {
        HStack(spacing: 10) {
            cityMenu(tr("From", "Von"), city: model.start, symbol: "figure.walk", action: model.setStart)
            Button(action: model.swap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .disabled(model.start == nil || model.goal == nil)
            .accessibilityLabel(tr("Swap start and goal", "Start und Ziel tauschen"))
            cityMenu(tr("To", "Nach"), city: model.goal, symbol: "flag.fill", action: model.setGoal)
            Spacer(minLength: 0)
            Menu {
                Picker(tr("Roads per city", "Straßen pro Stadt"), selection: Binding(
                    get: { model.neighbors },
                    set: { model.setNeighbors($0) }
                )) {
                    ForEach(2...5, id: \.self) { count in
                        Text(tr("\(count) nearest cities", "\(count) nächste Städte")).tag(count)
                    }
                }
            } label: {
                Label(tr("\(model.neighbors) roads per city", "\(model.neighbors) Straßen pro Stadt"), systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
    }

    private func cityMenu(_ title: String, city: City?, symbol: String, action: @escaping (City) -> Void) -> some View {
        Menu {
            ForEach(model.cities.sorted { $0.displayName < $1.displayName }) { option in
                Button(option.displayName) { action(option) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(city?.displayName ?? tr("Choose…", "Wählen…"), systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(city == nil ? .secondary : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var hint: some View {
        HStack(spacing: 16) {
            Image(systemName: "hand.tap")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(model.cities.count < 2
                ? tr("Choose at least 2 cities in Settings.", "Wähle in den Einstellungen mindestens 2 Städte.")
                : model.start == nil
                    ? tr("Tap a city on the map to choose the start.", "Tippe eine Stadt auf der Karte an, um den Start zu wählen.")
                    : tr("Now tap the goal.", "Tippe jetzt das Ziel an."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: Playback

    private func content(for step: DijkstraStep) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(step.message)
                .font(.callout)
                .lineLimit(3, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Slider(
                value: Binding(
                    get: { Double(model.stepIndex) },
                    set: { model.scrub(to: Int($0.rounded())) }
                ),
                in: 0...Double(max(model.steps.count - 1, 1)),
                step: 1
            )

            HStack {
                HStack(spacing: 12) {
                    speedMenu
                    Text(tr("Step \(model.stepIndex + 1) of \(model.steps.count)", "Schritt \(model.stepIndex + 1) von \(model.steps.count)"))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                transport
                distance(for: step)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 22) {
            Button(action: model.rewind) {
                Image(systemName: "backward.end.fill")
            }
            .accessibilityLabel(tr("Back to start", "Zum Anfang"))

            Button(action: model.stepBackward) {
                Image(systemName: "backward.frame.fill")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .accessibilityLabel(tr("Previous step", "Vorheriger Schritt"))

            Button(action: model.togglePlay) {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(.tint))
                    .contentTransition(.symbolEffect(.replace))
            }
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(model.isPlaying ? tr("Pause", "Pause") : tr("Play", "Abspielen"))

            Button(action: model.stepForward) {
                Image(systemName: "forward.frame.fill")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .accessibilityLabel(tr("Next step", "Nächster Schritt"))

            Button(action: model.jumpToEnd) {
                Image(systemName: "forward.end.fill")
            }
            .accessibilityLabel(tr("Jump to result", "Zum Ergebnis"))
        }
        .font(.title3)
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var speedMenu: some View {
        Menu {
            Picker(tr("Speed", "Tempo"), selection: Bindable(model.explorer).speed) {
                ForEach(PlaybackSpeed.allCases) { speed in
                    Text(speed.title).tag(speed)
                }
            }
        } label: {
            Label(model.explorer.speed.title, systemImage: "gauge.with.dots.needle.33percent")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    /// The final path length, or the goal's tentative distance while searching.
    private func distance(for step: DijkstraStep) -> some View {
        let goalDistance = model.cities.firstIndex { $0.id == model.goalID }.flatMap { step.distances[$0] }
        return VStack(alignment: .trailing, spacing: 1) {
            Text((step.length ?? goalDistance).map(\.km) ?? "∞")
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.snappy, value: goalDistance)
            Text(step.length != nil ? tr("Shortest path", "Kürzester Weg") : tr("Best so far to goal", "Bisher bis zum Ziel"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Info

struct DijkstraInfoView: View {
    private var steps: [String] {
        [
            tr("Give the start distance 0 and every other city distance ∞.",
               "Gib dem Start die Entfernung 0 und allen anderen Städten ∞."),
            tr("Pick the open city with the smallest distance. Its distance is now final, because every other route would have to pass through a city that is already farther away.",
               "Wähle die offene Stadt mit der kleinsten Entfernung. Ihre Entfernung steht jetzt fest, denn jeder andere Weg müsste über eine Stadt führen, die schon weiter weg ist."),
            tr("Check each road from that city: if going through it is shorter than a neighbour's current distance, update the neighbour.",
               "Prüfe jede Straße von dieser Stadt aus: Ist der Weg darüber kürzer als die bisherige Entfernung eines Nachbarn, aktualisiere den Nachbarn."),
            tr("Repeat until the goal is final, then follow the remembered roads back to the start.",
               "Wiederhole das, bis das Ziel feststeht, und folge dann den gemerkten Straßen zurück zum Start."),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(tr("Shortest Path", "Kürzester Weg"), systemImage: "arrow.triangle.turn.up.right.diamond")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(tr("Dijkstra's Algorithm", "Dijkstra-Algorithmus"))
                        .font(.title2.weight(.bold))
                    Text(tr(
                        "Edsger Dijkstra's algorithm from 1956 finds the shortest path between two places in a network, as route planners do. It spreads out from the start like a wave, always finishing the closest city first. Here every city has roads to its nearest neighbours, since with a direct road between every pair the direct one would always be shortest.",
                        "Der Algorithmus von Edsger Dijkstra aus dem Jahr 1956 findet den kürzesten Weg zwischen zwei Orten in einem Netz, wie es Routenplaner tun. Er breitet sich wie eine Welle vom Start aus und schließt immer zuerst die nächstgelegene Stadt ab. Hier hat jede Stadt Straßen zu ihren nächsten Nachbarn, denn gäbe es zwischen allen Städten eine direkte Straße, wäre die immer am kürzesten."
                    ))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("How It Works", "So funktioniert's"))
                        .font(.headline)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(.tint))
                            Text(text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(spacing: 12) {
                    FactTile(title: tr("Running Time", "Laufzeit"), value: tr("O(n²), or O(m log n) with a heap", "O(n²), mit Heap O(m log n)"))
                    FactTile(title: tr("Result", "Ergebnis"), value: tr("Always the shortest path (roads can't be negative)", "Immer der kürzeste Weg (keine negativen Straßen)"))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("On the Map", "Auf der Karte"))
                        .font(.headline)
                    LegendRow(color: Palette.ghost.opacity(0.55), label: tr("Road", "Straße"))
                    LegendRow(color: Palette.tour.opacity(0.4), label: tr("Best known road to each city", "Beste bekannte Straße zu jeder Stadt"))
                    LegendRow(color: Palette.candidate, label: tr("Road that just shortened a distance", "Straße, die gerade eine Entfernung verkürzt hat"))
                    LegendRow(color: Palette.removed, dashed: true, label: tr("Road checked, but no shorter", "Straße geprüft, aber nicht kürzer"))
                    LegendRow(color: Palette.tour, label: tr("Shortest path", "Kürzester Weg"))
                    Text(tr("Filled cities are final, orange-ringed ones have a tentative distance. Tap a city to set the start, then the goal.",
                            "Ausgefüllte Städte stehen fest, orange umrandete haben eine vorläufige Entfernung. Tippe eine Stadt an, um den Start und dann das Ziel festzulegen."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(24)
        }
    }
}
