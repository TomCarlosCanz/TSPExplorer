import SwiftUI
import MapKit
import Observation

/// State of the shortest-path tab: start and goal, the road network, and playback of
/// Dijkstra's algorithm. The cities come from the shared `ExplorerModel` settings.
@MainActor
@Observable
final class ShortestPathModel {
    let explorer: ExplorerModel

    private(set) var startID: String?
    private(set) var goalID: String?
    /// How many nearest neighbours each city has a road to.
    private(set) var neighbors = 3
    private(set) var network: RoadNetwork?
    private(set) var steps: [DijkstraStep] = []
    private(set) var stepIndex = 0
    private(set) var isPlaying = false
    var cameraPosition: MapCameraPosition = .automatic

    @ObservationIgnored private var playTask: Task<Void, Never>?
    /// The cities and language the steps were computed for, to notice changes made in Settings.
    @ObservationIgnored private var syncedCities: [String] = []
    @ObservationIgnored private var syncedVisibleCities: [String] = []
    @ObservationIgnored private var syncedLanguage = Localization.shared.language

    init(explorer: ExplorerModel) {
        self.explorer = explorer
        syncedCities = explorer.activeCities.map(\.id)
        syncedVisibleCities = explorer.visibleCities.map(\.id)
        recompute()
        fitCamera(animated: false)
    }

    /// Recomputes if the cities or language changed, and reframes the map if the region did.
    func sync() {
        let visible = explorer.visibleCities.map(\.id)
        let active = cities.map(\.id)
        let language = Localization.shared.language
        if visible != syncedVisibleCities { fitCamera() }
        guard visible != syncedVisibleCities || active != syncedCities || language != syncedLanguage else { return }
        syncedVisibleCities = visible
        syncedCities = active
        syncedLanguage = language
        recompute()
    }

    var cities: [City] { explorer.activeCities }

    var start: City? { cities.first { $0.id == startID } }
    var goal: City? { cities.first { $0.id == goalID } }

    var currentStep: DijkstraStep? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }

    var isAtEnd: Bool { !steps.isEmpty && stepIndex >= steps.count - 1 }

    // MARK: Start and goal

    /// Tapping a city sets the start, then the goal; a third tap starts over.
    func tap(_ city: City) {
        if start == nil || (goal != nil && city.id != goalID) {
            startID = city.id
            goalID = nil
        } else if city.id != startID {
            goalID = city.id
        }
        recompute()
    }

    func setStart(_ city: City) {
        if city.id == goalID { goalID = startID }
        startID = city.id
        recompute()
    }

    func setGoal(_ city: City) {
        if city.id == startID { startID = goalID }
        goalID = city.id
        recompute()
    }

    func swap() {
        (startID, goalID) = (goalID, startID)
        recompute()
    }

    func setNeighbors(_ count: Int) {
        neighbors = count
        recompute()
    }

    /// Builds the road network and runs Dijkstra once, recording every step.
    func recompute() {
        pause()
        let cities = cities
        // Forget a start or goal that is no longer on the map.
        if start == nil { startID = nil }
        if goal == nil { goalID = nil }
        network = cities.count >= 2 ? RoadNetwork(DistanceMatrix(cities: cities), neighbors: neighbors) : nil
        stepIndex = 0
        guard let network,
              let start = cities.firstIndex(where: { $0.id == startID }),
              let goal = cities.firstIndex(where: { $0.id == goalID })
        else {
            steps = []
            return
        }
        steps = Dijkstra.run(network, start: start, goal: goal, names: cities.map(\.displayName))
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
                try? await Task.sleep(nanoseconds: self.explorer.speed.nanoseconds)
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

    /// Frames all visible cities, leaving room at the bottom for the card.
    func fitCamera(animated: Bool = true) {
        let points = explorer.visibleCities.map { MKMapPoint($0.coordinate) }
        guard !points.isEmpty else { return }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let width = max(maxX - minX, 200_000)
        let height = max(maxY - minY, 200_000)
        let rect = MKMapRect(x: minX - width * 0.12, y: minY - height * 0.15, width: width * 1.24, height: height * 2.1)
        if animated {
            withAnimation(.smooth(duration: 0.8)) { cameraPosition = .rect(rect) }
        } else {
            cameraPosition = .rect(rect)
        }
    }
}
