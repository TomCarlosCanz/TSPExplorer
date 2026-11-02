import Foundation

/// Concorde (Applegate, Bixby, Chvátal & Cook), the record-holding exact TSP solver.
/// It needs a C toolchain and an LP solver, so it can't run on an iPad. Instead it is
/// run ahead of time on a Mac (see the Concorde/ folder next to the Xcode project)
/// and its results are bundled as concorde_results.json. This replays them.
enum Concorde {
    /// One solved city set, as written by Concorde/generate_results.py.
    struct Instance: Decodable {
        /// City IDs in matrix order; all indices below refer to this order.
        let cities: [String]
        let tour: [Int]
        /// "heldKarp" below 10 cities, otherwise "branchAndCut".
        let method: String
        let seconds: Double?
        let bbNodes: Int?
        /// Concorde's Lin–Kernighan starting tour.
        let lkTour: [Int]?
        /// Cutting-plane stages, weakest first.
        let stages: [Stage]?
    }

    /// The LP after one cutting-plane stage.
    struct Stage: Decodable {
        /// "matching", "subtour", "blossom" or "root".
        let name: String
        /// LP value in metres.
        let bound: Double
        /// [city, city, x] for every connection with x > 0.
        let x: [[Double]]
    }

    private struct Results: Decodable {
        let solver: String
        let generated: String
        let instances: [Instance]
    }

    private static let results: Results? = {
        guard let url = Bundle.main.url(forResource: "concorde_results", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Results.self, from: data)
    }()

    private static let solved: [[String]: Instance] = Dictionary(
        (results?.instances ?? []).map { ($0.cities, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// Whether the bundle contains any Concorde results at all.
    static var isBundled: Bool { results != nil }

    /// The precomputed result for exactly these cities in this order, if there is one.
    static func result(for cities: [City]) -> Instance? {
        solved[cities.map(\.id)]
    }

    /// Length of the optimal tour through these cities, if Concorde solved them.
    static func optimalLength(_ m: DistanceMatrix, cities: [City]) -> Double? {
        guard let result = result(for: cities), result.tour.count == m.count else { return nil }
        return m.length(of: result.tour)
    }

    static func run(_ m: DistanceMatrix, cities: [City]) -> [SolverStep] {
        guard let result = result(for: cities), result.tour.count == m.count else { return [] }
        let n = m.count
        let optimal = m.length(of: result.tour)
        var steps: [SolverStep] = []

        let time = result.seconds.map {
            $0 < 0.01 ? " in under a hundredth of a second" : " in " + $0.formatted(.number.precision(.fractionLength(2))) + " seconds"
        } ?? ""
        // (n−1)!/2 tours, written as a power of ten once it's too big to read.
        let tourDigits = (2..<n).reduce(-log10(2.0)) { $0 + log10(Double($1)) }
        let tourCount = n > BranchAndBound.maxCities
            ? " There are about 10\(superscript(Int(tourDigits))) possible tours, far too many to ever check one by one."
            : ""
        steps.append(SolverStep(
            "Concorde can't run on an iPad, so it solved these \(n) cities ahead of time on a Mac\(time).\(tourCount) Its idea: squeeze the optimum between a good tour from above and a proven bound from below.",
            focus: Array(0..<n)
        ))

        if result.method == "heldKarp" {
            steps.append(SolverStep(
                "With fewer than 10 cities, Concorde skips its linear-programming machinery and uses Held–Karp dynamic programming: it works out the shortest path to every city through every subset of cities, which takes about n²·2ⁿ steps instead of n!.",
                focus: Array(0..<n)
            ))
            var final = SolverStep(
                "Optimal tour: \(optimal.km), starting at \(cities[result.tour[0]].name). Held–Karp covers every possible tour, so nothing shorter exists.",
                path: result.tour,
                closed: true,
                length: optimal
            )
            final.isOptimal = true
            steps.append(final)
            return steps
        }

        let upper = result.lkTour.map { m.length(of: $0) }
        if let lkTour = result.lkTour, let upper {
            var step = SolverStep(
                "Upper bound: Lin–Kernighan, a local search that keeps rearranging chains of connections, finds a tour of \(upper.km). The optimum can't be longer than that.",
                path: lkTour,
                closed: true,
                length: upper
            )
            step.lengthKind = .upperBound
            step.upperBound = upper
            steps.append(step)
        }

        var best: Double?
        for (number, stage) in (result.stages ?? []).enumerated() {
            let bound = stage.bound / 1000
            var whole: [Edge] = []
            var fractional: [Edge] = []
            for row in stage.x where row.count == 3 {
                let edge = Edge(Int(row[0]), Int(row[1]))
                if row[2] > 0.999 { whole.append(edge) } else { fractional.append(edge) }
            }
            let weaker = best.map { bound < $0 - 0.001 } ?? false
            let isTour = fractional.isEmpty && loops(whole, count: n) == 1

            var text = "Lower bound, step \(number + 1): " + explanation(of: stage.name, bound: bound)
            if isTour {
                text += " The LP picks one complete tour, so the bound equals a real tour's length."
            } else if fractional.isEmpty {
                text += " The answer is \(loops(whole, count: n)) separate loops, which no real tour is."
            } else {
                text += " Orange connections are used only half, which no real tour can do."
            }
            if weaker, let best {
                text += " That's weaker than before, so the best bound stays \(best.km)."
            }
            best = max(best ?? bound, bound)

            var step = SolverStep(
                text,
                edges: whole,
                candidates: fractional,
                ghost: result.lkTour ?? [],
                length: bound
            )
            step.lengthKind = .lowerBound
            step.lowerBound = best
            step.upperBound = upper
            steps.append(step)
        }

        let nodes = result.bbNodes ?? 1
        let branching = nodes > 1
            ? "Where the bounds didn't meet, Concorde split the problem in two (use a connection or don't) and solved \(nodes) LP subproblems."
            : "No branching was needed."
        var final = SolverStep(
            "The bounds meet at \(optimal.km): no tour can be shorter, so this one is proven optimal. \(branching)",
            path: result.tour,
            closed: true,
            length: optimal
        )
        final.isOptimal = true
        final.lowerBound = optimal
        final.upperBound = optimal
        steps.append(final)
        return steps
    }

    private static func explanation(of stage: String, bound: Double) -> String {
        switch stage {
        case "matching":
            return "drop the rule that the tour is one single loop and only ask that every city gets two connections. That easier problem costs \(bound.km), and every real tour is one of its solutions."
        case "subtour":
            return "add subtour cuts. Every group of cities must have two connections to the rest, which forbids separate loops. The linear program now gives \(bound.km)."
        case "blossom":
            return "add blossom cuts, which rule out odd rings of half-used connections. The bound rises to \(bound.km)."
        default:
            return "Concorde's full cutting loop adds comb inequalities and more, reaching \(bound.km)."
        }
    }

    /// 155 → "¹⁵⁵"
    private static func superscript(_ value: Int) -> String {
        let digits: [Character] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
        return String(String(value).compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }

    /// Number of separate pieces the connections split the cities into.
    private static func loops(_ edges: [Edge], count: Int) -> Int {
        var sets = UnionFind(count)
        for edge in edges { sets.union(edge.a, edge.b) }
        return Set((0..<count).map { sets.find($0) }).count
    }
}
