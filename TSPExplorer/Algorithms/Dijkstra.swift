import Foundation

/// A road network between the cities. On the complete graph the direct connection
/// is always the shortest path, so every city is only linked to its nearest
/// neighbours, plus the few extra roads needed to keep the network connected.
struct RoadNetwork {
    let edges: [Edge]
    /// Neighbours of each city with the length of the road in kilometres.
    let adjacency: [[(city: Int, length: Double)]]

    init(_ matrix: DistanceMatrix, neighbors: Int) {
        let n = matrix.count
        var roads = Set<Edge>()
        for i in 0..<n {
            let nearest = (0..<n).filter { $0 != i }.sorted { matrix[i, $0] < matrix[i, $1] }
            for j in nearest.prefix(neighbors) { roads.insert(Edge(i, j)) }
        }

        // Join separate clusters with their shortest connections (as in Kruskal's algorithm).
        var components = UnionFind(n)
        for road in roads { components.union(road.a, road.b) }
        var pairs: [Edge] = []
        for i in 0..<n {
            for j in (i + 1)..<n { pairs.append(Edge(i, j)) }
        }
        pairs.sort { matrix[$0.a, $0.b] < matrix[$1.a, $1.b] }
        for pair in pairs where components.find(pair.a) != components.find(pair.b) {
            components.union(pair.a, pair.b)
            roads.insert(pair)
        }

        edges = roads.sorted { ($0.a, $0.b) < ($1.a, $1.b) }
        var adjacency = Array(repeating: [(city: Int, length: Double)](), count: n)
        for road in edges {
            adjacency[road.a].append((road.b, matrix[road.a, road.b]))
            adjacency[road.b].append((road.a, matrix[road.a, road.b]))
        }
        self.adjacency = adjacency
    }
}

/// One frame of Dijkstra's algorithm.
struct DijkstraStep {
    var message: String
    /// Tentative distance from the start for every city; `nil` means ∞.
    var distances: [Double?]
    /// Cities whose shortest distance is final.
    var settled: Set<Int>
    /// The city being settled or whose roads are being checked.
    var current: Int?
    /// Roads that just gave a neighbour a shorter distance.
    var improved: [Edge] = []
    /// Roads checked that didn't help.
    var rejected: [Edge] = []
    /// The best known road into each reached city (shortest-path tree).
    var tree: [Edge]
    /// The final shortest path from start to goal.
    var path: [Int] = []
    var length: Double?

    init(
        _ message: String,
        distances: [Double?],
        settled: Set<Int>,
        current: Int?,
        improved: [Edge] = [],
        rejected: [Edge] = [],
        tree: [Edge],
        path: [Int] = [],
        length: Double? = nil
    ) {
        self.message = message
        self.distances = distances
        self.settled = settled
        self.current = current
        self.improved = improved
        self.rejected = rejected
        self.tree = tree
        self.path = path
        self.length = length
    }
}

enum Dijkstra {
    static func run(_ network: RoadNetwork, start: Int, goal: Int, names: [String]) -> [DijkstraStep] {
        let n = network.adjacency.count
        var distances = [Double?](repeating: nil, count: n)
        var previous = [Int?](repeating: nil, count: n)
        var settled = Set<Int>()
        distances[start] = 0

        func tree() -> [Edge] {
            previous.enumerated().compactMap { city, from in from.map { Edge($0, city) } }
        }

        var steps = [DijkstraStep(
            tr("Start in \(names[start]) with distance 0. Every other city is still ∞ away.",
               "Start in \(names[start]) mit Entfernung 0. Alle anderen Städte sind noch ∞ weit weg."),
            distances: distances, settled: settled, current: start, tree: []
        )]

        while true {
            // The unsettled city with the smallest tentative distance.
            guard let city = (0..<n)
                .filter({ !settled.contains($0) && distances[$0] != nil })
                .min(by: { distances[$0]! < distances[$1]! }),
                let distance = distances[city]
            else {
                steps.append(DijkstraStep(
                    tr("\(names[goal]) can't be reached from \(names[start]).",
                       "\(names[goal]) ist von \(names[start]) aus nicht erreichbar."),
                    distances: distances, settled: settled, current: nil, tree: tree()
                ))
                return steps
            }

            settled.insert(city)
            if city == goal { break }
            steps.append(DijkstraStep(
                tr("\(names[city]) is the closest open city (\(distance.km)). No detour can be shorter, so its distance is final.",
                   "\(names[city]) ist die nächste offene Stadt (\(distance.km)). Kein Umweg kann kürzer sein, also steht ihre Entfernung fest."),
                distances: distances, settled: settled, current: city, tree: tree()
            ))

            var improved: [Edge] = []
            var rejected: [Edge] = []
            var updates: [String] = []
            for (neighbor, length) in network.adjacency[city] where !settled.contains(neighbor) {
                let candidate = distance + length
                if distances[neighbor].map({ candidate < $0 }) ?? true {
                    distances[neighbor] = candidate
                    previous[neighbor] = city
                    improved.append(Edge(city, neighbor))
                    updates.append("\(names[neighbor]) → \(candidate.km)")
                } else {
                    rejected.append(Edge(city, neighbor))
                }
            }
            guard !improved.isEmpty || !rejected.isEmpty else { continue }
            let message = improved.isEmpty
                ? tr("No road from \(names[city]) shortens a distance.",
                     "Keine Straße von \(names[city]) verkürzt eine Entfernung.")
                : tr("Roads from \(names[city]) give shorter distances: ", "Straßen von \(names[city]) verkürzen Entfernungen: ")
                    + updates.joined(separator: ", ")
            steps.append(DijkstraStep(
                message, distances: distances, settled: settled, current: city,
                improved: improved, rejected: rejected, tree: tree()
            ))
        }

        var path = [goal]
        while let from = previous[path[0]] { path.insert(from, at: 0) }
        let length = distances[goal] ?? 0
        steps.append(DijkstraStep(
            tr("\(names[goal]) reached: the shortest path is \(length.km) via \(path.count - 2) stops. \(settled.count) of \(n) cities were settled.",
               "\(names[goal]) erreicht: Der kürzeste Weg ist \(length.km) lang, mit \(path.count - 2) Zwischenstopps. \(settled.count) von \(n) Städten wurden abgeschlossen."),
            distances: distances, settled: settled, current: goal, tree: tree(), path: path, length: length
        ))
        return steps
    }
}
