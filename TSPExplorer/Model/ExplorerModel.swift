import SwiftUI
import MapKit
import Observation

enum PlaybackSpeed: String, CaseIterable, Identifiable {
    case slow, normal, fast, faster, fastest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow: return tr("0.5×", "0,5×")
        case .normal: return "1×"
        case .fast: return "2×"
        case .faster: return "4×"
        case .fastest: return "10×"
        }
    }

    var nanoseconds: UInt64 {
        switch self {
        case .slow: return 1_400_000_000
        case .normal: return 700_000_000
        case .fast: return 350_000_000
        case .faster: return 175_000_000
        case .fastest: return 70_000_000
        }
    }
}

struct ComparisonResult: Identifiable {
    let algorithm: Algorithm
    let length: Double
    let isOptimal: Bool
    /// The final tour, so the results can show it on the map.
    let tour: [Int]
    /// The optimum if Concorde solved these cities, otherwise the best length found.
    var best: Double = 0
    var bestIsOptimal = false

    var id: String { algorithm.id }
    var isBest: Bool { length <= best + 0.5 }

    var gapText: String {
        if isBest { return isOptimal || bestIsOptimal ? tr("Optimal", "Optimal") : tr("Best found", "Bestes Ergebnis") }
        return "+" + OptimalGap.percent(length, best) + tr("%", " %")
    }
}

enum OptimalGap {
    /// "4.2" for a tour 4.2% longer than `optimal`.
    static func percent(_ length: Double, _ optimal: Double) -> String {
        (max(0, length / optimal - 1) * 100).formatted(.number.precision(.fractionLength(1)).locale(Localization.shared.language.locale))
    }

    /// "+4.2% vs optimal", or "Optimal length" when it matches.
    static func text(_ length: Double, _ optimal: Double) -> String {
        length <= optimal + 0.5
            ? tr("Optimal length", "Optimale Länge")
            : tr("+\(percent(length, optimal))% vs optimal", "+\(percent(length, optimal)) % über Optimum")
    }
}

/// App state: which cities, which algorithm, and where playback currently is.
@MainActor
@Observable
final class ExplorerModel {
    private(set) var region: Region = .europe
    private(set) var cityCount = 10
    private(set) var customCities: [City] = []
    private(set) var excluded: Set<String> = []
    private(set) var algorithm: Algorithm = .concorde
    /// The last chapter of the presentation: every algorithm's result side by side.
    private(set) var showingResults = false
    private(set) var results: [ComparisonResult] = []
    /// The result whose tour is drawn on the map while showing results.
    var highlightedResult: Algorithm?

    var showNames = true
    var speed: PlaybackSpeed = .normal
    var cameraPosition: MapCameraPosition = .automatic

    private(set) var steps: [SolverStep] = []
    /// Optimal tour length for the current cities, if Concorde solved them ahead of time.
    private(set) var optimalLength: Double?
    private(set) var stepIndex = 0
    private(set) var isPlaying = false

    @ObservationIgnored private var playTask: Task<Void, Never>?

    init() {
        recompute()
        fitCamera(animated: false)
    }

    // MARK: Cities

    /// Cities shown on the map (preset + your own), including ones tapped off.
    var visibleCities: [City] {
        Array(region.cities.prefix(cityCount)) + customCities
    }

    /// Cities that take part in the tour, in matrix order.
    var activeCities: [City] {
        visibleCities.filter { !excluded.contains($0.id) }
    }

    var currentStep: SolverStep? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }

    /// What the map shows: the current animation frame, or on the results page the
    /// highlighted algorithm's tour over the optimal (or best) tour.
    var displayStep: SolverStep? {
        guard showingResults else { return currentStep }
        let reference = results.first { $0.algorithm == .concorde } ?? results.first
        guard let shown = results.first(where: { $0.algorithm == highlightedResult }) ?? reference else { return nil }
        return SolverStep(
            "",
            path: shown.tour,
            closed: true,
            ghost: shown.algorithm == reference?.algorithm ? [] : reference?.tour ?? [],
            length: shown.length
        )
    }

    var exceedsLimit: Bool {
        guard let limit = algorithm.maxCities else { return false }
        return activeCities.count > limit
    }

    /// Concorde only has results for the city sets it was run on ahead of time.
    var missingPrecomputed: Bool {
        algorithm == .concorde && activeCities.count >= 3 && Concorde.result(for: activeCities) == nil
    }

    func setRegion(_ newRegion: Region) {
        guard newRegion != region else { return }
        region = newRegion
        cityCount = min(cityCount, newRegion.cities.count)
        excluded = []
        citiesChanged()
        fitCamera()
    }

    func setCityCount(_ count: Int) {
        cityCount = max(3, min(count, region.cities.count))
        citiesChanged()
        fitCamera()
    }

    func toggle(_ city: City) {
        if excluded.contains(city.id) {
            excluded.remove(city.id)
        } else {
            excluded.insert(city.id)
        }
        citiesChanged()
    }

    func includeAll() {
        excluded = []
        citiesChanged()
    }

    func addCustom(_ city: City) {
        guard !customCities.contains(where: { $0.id == city.id }) else { return }
        customCities.append(city)
        citiesChanged()
        fitCamera()
    }

    func removeCustom(at offsets: IndexSet) {
        customCities.remove(atOffsets: offsets)
        citiesChanged()
        fitCamera()
    }

    /// Recomputes, and moves on if the current algorithm can't handle this many cities.
    private func citiesChanged() {
        recompute()
        if exceedsLimit && !showingResults { nextChapter() }
    }

    // MARK: Presentation

    /// Chapters: every algorithm in presentation order, then the results.
    static let chapterCount = Algorithm.allCases.count + 1

    var chapterIndex: Int {
        showingResults ? Algorithm.allCases.count : Algorithm.allCases.firstIndex(of: algorithm) ?? 0
    }

    var isAtEnd: Bool { !steps.isEmpty && stepIndex >= steps.count - 1 }

    func goToChapter(_ index: Int) {
        if index >= Algorithm.allCases.count {
            showResults()
        } else if Algorithm.allCases.indices.contains(index) {
            select(Algorithm.allCases[index])
        }
    }

    /// Whether the algorithm can run on the current cities (exact search is limited).
    func isUsable(_ candidate: Algorithm) -> Bool {
        guard let limit = candidate.maxCities else { return true }
        return activeCities.count <= limit
    }

    /// The next chapter, skipping algorithms that can't handle this many cities.
    func nextChapter() {
        var index = chapterIndex + 1
        while index < Algorithm.allCases.count && !isUsable(Algorithm.allCases[index]) { index += 1 }
        goToChapter(index)
    }

    /// The previous usable algorithm, if there is one.
    var previousUsableChapter: Int? {
        var index = chapterIndex - 1
        while index >= 0 && !isUsable(Algorithm.allCases[index]) { index -= 1 }
        return index >= 0 ? index : nil
    }

    func previousChapter() {
        if let index = previousUsableChapter { goToChapter(index) }
    }

    func showResults() {
        pause()
        showingResults = true
        highlightedResult = nil
        results = comparison()
        fitCamera()
    }

    // MARK: Algorithm

    func select(_ newAlgorithm: Algorithm) {
        guard newAlgorithm != algorithm || showingResults else { return }
        let wasShowingResults = showingResults
        showingResults = false
        algorithm = newAlgorithm
        recompute()
        if wasShowingResults { fitCamera() }
    }

    /// Runs the selected algorithm once and records every step for playback.
    func recompute() {
        pause()
        defer { if showingResults { results = comparison() } }
        let cities = activeCities
        guard cities.count >= 3, !exceedsLimit, !missingPrecomputed else {
            steps = []
            stepIndex = 0
            optimalLength = nil
            return
        }
        let matrix = DistanceMatrix(cities: cities)
        optimalLength = Concorde.optimalLength(matrix, cities: cities)
        steps = algorithm.solve(matrix, cities: cities)
        stepIndex = 0
    }

    /// Final tour length of every algorithm on the current cities, shortest first.
    func comparison() -> [ComparisonResult] {
        let cities = activeCities
        guard cities.count >= 3 else { return [] }
        let matrix = DistanceMatrix(cities: cities)
        var results: [ComparisonResult] = []
        for candidate in Algorithm.allCases {
            if let limit = candidate.maxCities, cities.count > limit { continue }
            guard let last = candidate.solve(matrix, cities: cities).last, let length = last.length else { continue }
            results.append(ComparisonResult(algorithm: candidate, length: length, isOptimal: last.isOptimal, tour: last.path))
        }
        let optimal = Concorde.optimalLength(matrix, cities: cities)
        let best = optimal ?? results.map(\.length).min() ?? 0
        // Shortest first, but Concorde, the reference, leads any tie. Ties are within
        // half a kilometre, since the same tour can differ by metres of rounding.
        return results
            .sorted { a, b in
                abs(a.length - b.length) > 0.5 ? a.length < b.length : a.algorithm == .concorde && b.algorithm != .concorde
            }
            .map { result in
                var copy = result
                copy.best = best
                copy.bestIsOptimal = optimal != nil
                return copy
            }
    }

    // MARK: Playback

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard steps.count > 1 else { return }
        if stepIndex >= steps.count - 1 { stepIndex = 0 }
        isPlaying = true
        playTask?.cancel()
        playTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(nanoseconds: self.speed.nanoseconds)
                guard self.isPlaying, !Task.isCancelled else { return }
                if self.stepIndex < self.steps.count - 1 {
                    self.stepIndex += 1
                } else {
                    self.isPlaying = false
                    return
                }
            }
        }
    }

    func pause() {
        isPlaying = false
        playTask?.cancel()
        playTask = nil
    }

    func stepForward() {
        pause()
        if stepIndex < steps.count - 1 { stepIndex += 1 }
    }

    func stepBackward() {
        pause()
        if stepIndex > 0 { stepIndex -= 1 }
    }

    func rewind() {
        pause()
        stepIndex = 0
    }

    func jumpToEnd() {
        pause()
        stepIndex = max(0, steps.count - 1)
    }

    func scrub(to index: Int) {
        pause()
        stepIndex = max(0, min(index, steps.count - 1))
    }

    // MARK: Camera

    /// Frames all visible cities, leaving room at the bottom for the card, which is
    /// taller on the results page.
    func fitCamera(animated: Bool = true) {
        let cities = visibleCities
        guard !cities.isEmpty else { return }
        let points = cities.map { MKMapPoint($0.coordinate) }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let width = max(maxX - minX, 200_000)
        let height = max(maxY - minY, 200_000)
        let rect = MKMapRect(
            x: minX - width * 0.12,
            y: minY - height * 0.15,
            width: width * 1.24,
            height: height * (showingResults ? 2.6 : 1.9)
        )
        if animated {
            withAnimation(.smooth(duration: 0.8)) { cameraPosition = .rect(rect) }
        } else {
            cameraPosition = .rect(rect)
        }
    }
}
