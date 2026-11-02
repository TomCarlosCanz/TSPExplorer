import Foundation

/// Exact depth-first branch and bound. Proves optimality for small instances.
enum BranchAndBound {
    static let maxCities = 12

    static func run(_ m: DistanceMatrix, names: [String]) -> [SolverStep] {
        var search = Search(m: m, names: names)
        return search.run()
    }

    private struct Search {
        let m: DistanceMatrix
        let names: [String]
        let n: Int

        var steps: [SolverStep] = []
        var path: [Int] = [0]
        var visited: [Bool]
        var best: [Int]
        var bestLength: Double

        var nodes = 0
        var skippedTours = 0.0
        var recorded = 0
        var budgetReached = false

        let nodeBudget = 750_000
        let maxRecorded = 450
        /// Depths at which explore/prune events are shown. Deeper levels are
        /// still searched, just not animated — there are far too many of them.
        let exploreDepth: Int
        let pruneDepth: Int

        init(m: DistanceMatrix, names: [String]) {
            let count = m.count
            var startVisited = Array(repeating: false, count: count)
            startVisited[0] = true
            let initialTour = NearestNeighbor.tour(m)

            self.m = m
            self.names = names
            self.n = count
            self.visited = startVisited
            self.best = initialTour
            self.bestLength = m.length(of: initialTour)
            self.exploreDepth = count <= 7 ? count : 3
            self.pruneDepth = count <= 7 ? count : 4
        }

        mutating func run() -> [SolverStep] {
            let allTours = TourUtils.factorial(n - 1) / 2
            steps.append(SolverStep(
                "There are \(TourUtils.count(allTours)) different tours through \(n) cities. Instead of checking them all, start with a quick nearest-neighbor tour (\(bestLength.km)) as the bar to beat.",
                ghost: best,
                focus: [0],
                length: bestLength
            ))

            explore(cost: 0)

            var summary = SolverStep(
                budgetReached
                    ? "Search budget reached after \(TourUtils.count(Double(nodes))) partial routes. Best tour found: \(bestLength.km), but not proven optimal."
                    : "Search complete: this tour is proven optimal at \(bestLength.km). Only \(TourUtils.count(Double(nodes))) partial routes were examined; pruning skipped about \(TourUtils.count(skippedTours)) complete tours.",
                path: best,
                closed: true,
                length: bestLength
            )
            summary.isOptimal = !budgetReached
            steps.append(summary)
            return steps
        }

        /// Lower bound for completing the current partial route: the route so far,
        /// plus the cheapest way out of the current city, plus — for every unvisited
        /// city — the cheapest way to leave it (to another unvisited city or home).
        func lowerBound(cost: Double) -> Double {
            var bound = cost
            let current = path[path.count - 1]
            var cheapestOut = Double.infinity
            for c in 0..<n where !visited[c] {
                cheapestOut = min(cheapestOut, m[current, c])
            }
            if cheapestOut.isFinite { bound += cheapestOut }
            for u in 0..<n where !visited[u] {
                var cheapest = m[u, 0]
                for v in 0..<n where !visited[v] && v != u {
                    cheapest = min(cheapest, m[u, v])
                }
                bound += cheapest
            }
            return bound
        }

        func describe(_ route: [Int]) -> String {
            route.map { names[$0] }.joined(separator: " → ")
        }

        mutating func explore(cost: Double) {
            if budgetReached { return }
            nodes += 1
            if nodes > nodeBudget {
                budgetReached = true
                return
            }

            let current = path[path.count - 1]

            if path.count == n {
                let total = cost + m[current, 0]
                if total < bestLength - 1e-9 {
                    bestLength = total
                    best = path
                    steps.append(SolverStep(
                        "New best tour: \(total.km). From now on, every branch has to beat this.",
                        path: path,
                        closed: true,
                        candidates: [Edge(current, 0)],
                        length: total
                    ))
                }
                return
            }

            let children = (0..<n)
                .filter { !visited[$0] }
                .sorted { m[current, $0] < m[current, $1] }

            for child in children {
                let newCost = cost + m[current, child]
                path.append(child)
                visited[child] = true

                let bound = lowerBound(cost: newCost)
                if bound >= bestLength - 1e-9 {
                    let completions = TourUtils.factorial(n - path.count)
                    skippedTours += completions
                    if path.count <= pruneDepth && recorded < maxRecorded {
                        recorded += 1
                        steps.append(SolverStep(
                            "Prune \(describe(path)). Even the most optimistic finish needs ≥ \(bound.km), but we already have \(bestLength.km). That skips \(TourUtils.count(completions)) tours at once.",
                            path: path,
                            removed: [Edge(current, child)],
                            ghost: best,
                            focus: [child],
                            length: newCost
                        ))
                    }
                } else {
                    if path.count <= exploreDepth && recorded < maxRecorded {
                        recorded += 1
                        steps.append(SolverStep(
                            "Explore \(describe(path)). Lower bound \(bound.km) is below the best tour (\(bestLength.km)), so this branch might still win.",
                            path: path,
                            candidates: [Edge(current, child)],
                            ghost: best,
                            focus: [child],
                            length: newCost
                        ))
                    }
                    explore(cost: newCost)
                }

                path.removeLast()
                visited[child] = false
            }
        }
    }
}
