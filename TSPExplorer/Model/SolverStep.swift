import Foundation

/// An undirected connection between two cities (stored with a < b).
struct Edge: Hashable {
    let a: Int
    let b: Int

    init(_ x: Int, _ y: Int) {
        a = min(x, y)
        b = max(x, y)
    }
}

/// An edge drawn with a strength from 0 to 1 (pheromone, background tree, …).
struct WeightedEdge {
    let edge: Edge
    let weight: Double
}

/// One frame of an algorithm's animation. Every algorithm turns its work into
/// a list of these snapshots, which the app then plays back on the map.
struct SolverStep {
    /// Plain-language explanation of what happens in this frame.
    var message: String
    /// An ordered route through the cities (indices into the distance matrix).
    var path: [Int]
    /// Whether `path` returns to its first city.
    var isClosed: Bool
    /// Unordered edges that are part of the solution (Greedy Edge, spanning tree).
    var edges: [Edge]
    /// Edges currently being looked at or just added — drawn highlighted.
    var candidates: [Edge]
    /// Edges being rejected or removed — drawn red and dashed.
    var removed: [Edge]
    /// Background edges with varying strength — pheromone trails, the spanning tree.
    var weighted: [WeightedEdge]
    /// Best tour found so far — drawn as a gray dashed outline.
    var ghost: [Int]
    /// Cities to emphasise in this frame.
    var focus: [Int]
    /// Current length in kilometres (route, tour or tree, depending on the algorithm).
    var length: Double?
    /// Set on the final step when the tour is proven optimal.
    var isOptimal = false
    /// What `length` means when it isn't a plain distance.
    var lengthKind: LengthKind?
    /// Exact solvers: the best proven lower bound and the best tour so far, shown
    /// as the gap that closes until the tour is proven optimal.
    var lowerBound: Double?
    var upperBound: Double?

    init(
        _ message: String,
        path: [Int] = [],
        closed: Bool = false,
        edges: [Edge] = [],
        candidates: [Edge] = [],
        removed: [Edge] = [],
        weighted: [WeightedEdge] = [],
        ghost: [Int] = [],
        focus: [Int] = [],
        length: Double? = nil
    ) {
        self.message = message
        self.path = path
        self.isClosed = closed
        self.edges = edges
        self.candidates = candidates
        self.removed = removed
        self.weighted = weighted
        self.ghost = ghost
        self.focus = focus
        self.length = length
    }
}

enum LengthKind {
    case upperBound, lowerBound

    var title: String {
        switch self {
        case .upperBound: return tr("Upper bound", "Obere Schranke")
        case .lowerBound: return tr("Lower bound", "Untere Schranke")
        }
    }
}

/// Small, fast, seedable random number generator (SplitMix64), so every run
/// of a randomised algorithm is reproducible — useful when presenting.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Disjoint-set structure used by Greedy Edge to detect early loops.
struct UnionFind {
    private var parent: [Int]

    init(_ count: Int) {
        parent = Array(0..<count)
    }

    mutating func find(_ x: Int) -> Int {
        var root = x
        while parent[root] != root { root = parent[root] }
        var node = x
        while parent[node] != root {
            let next = parent[node]
            parent[node] = root
            node = next
        }
        return root
    }

    mutating func union(_ x: Int, _ y: Int) {
        let rx = find(x)
        let ry = find(y)
        if rx != ry { parent[rx] = ry }
    }
}

enum TourUtils {
    /// Turns a set of edges in which every city has degree 2 into an ordered tour.
    static func order(from edges: [Edge], count: Int) -> [Int] {
        var adjacency = Array(repeating: [Int](), count: count)
        for e in edges {
            adjacency[e.a].append(e.b)
            adjacency[e.b].append(e.a)
        }
        var route = [0]
        var previous = -1
        var current = 0
        while route.count < count {
            guard let next = adjacency[current].first(where: { $0 != previous }) else { break }
            route.append(next)
            previous = current
            current = next
        }
        return route
    }

    static func factorial(_ n: Int) -> Double {
        n <= 1 ? 1 : (2...n).reduce(1.0) { $0 * Double($1) }
    }

    /// "5,040" or "3.6M" for large numbers.
    static func count(_ value: Double) -> String {
        value < 100_000
            ? value.formatted(.number.precision(.fractionLength(0)))
            : value.formatted(.number.notation(.compactName).precision(.significantDigits(2)))
    }
}
