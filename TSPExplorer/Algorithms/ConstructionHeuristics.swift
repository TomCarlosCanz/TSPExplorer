import Foundation

// MARK: - Nearest Neighbor

enum NearestNeighbor {
    /// Plain tour without animation steps (used as a starting point elsewhere).
    static func tour(_ m: DistanceMatrix, start: Int = 0) -> [Int] {
        let n = m.count
        var route = [start]
        var visited = Array(repeating: false, count: n)
        visited[start] = true
        while route.count < n {
            let current = route[route.count - 1]
            var next = -1
            for c in 0..<n where !visited[c] {
                if next == -1 || m[current, c] < m[current, next] { next = c }
            }
            route.append(next)
            visited[next] = true
        }
        return route
    }

    static func run(_ m: DistanceMatrix, names: [String], start: Int = 0) -> [SolverStep] {
        let n = m.count
        var steps: [SolverStep] = []
        var route = [start]
        var visited = Array(repeating: false, count: n)
        visited[start] = true

        steps.append(SolverStep(
            "Start in \(names[start]). From here, always travel to the closest city that hasn't been visited yet.",
            path: route,
            focus: [start],
            length: 0
        ))

        while route.count < n {
            let current = route[route.count - 1]
            let unvisited = (0..<n).filter { !visited[$0] }
            var next = unvisited[0]
            for c in unvisited where m[current, c] < m[current, next] { next = c }

            steps.append(SolverStep(
                "From \(names[current]), compare the distances to all \(unvisited.count) unvisited cities.",
                path: route,
                candidates: unvisited.map { Edge(current, $0) },
                focus: [current],
                length: m.length(of: route, closed: false)
            ))

            route.append(next)
            visited[next] = true

            steps.append(SolverStep(
                "\(names[next]) is the closest (\(m[current, next].km)). Go there.",
                path: route,
                candidates: [Edge(current, next)],
                focus: [next],
                length: m.length(of: route, closed: false)
            ))
        }

        let last = route[route.count - 1]
        steps.append(SolverStep(
            "Every city is visited. Return from \(names[last]) to \(names[start]) (\(m[last, start].km)) to close the tour. Notice how the last legs are often long: that's the price of being greedy early.",
            path: route,
            closed: true,
            candidates: [Edge(last, start)],
            length: m.length(of: route)
        ))
        return steps
    }
}

// MARK: - Greedy Edge

enum GreedyEdge {
    static func run(_ m: DistanceMatrix, names: [String]) -> [SolverStep] {
        let n = m.count
        var all: [Edge] = []
        for i in 0..<n {
            for j in (i + 1)..<n { all.append(Edge(i, j)) }
        }
        all.sort { m[$0.a, $0.b] < m[$1.a, $1.b] }

        var degree = Array(repeating: 0, count: n)
        var components = UnionFind(n)
        var chosen: [Edge] = []
        var total = 0.0

        var steps = [SolverStep(
            "There are \(all.count) possible connections between \(n) cities. Sort them by length, then add them shortest-first, as long as no city gets more than two connections and no loop closes too early."
        )]

        for e in all {
            if chosen.count == n { break }
            let label = "\(names[e.a])–\(names[e.b]) (\(m[e.a, e.b].km))"

            if degree[e.a] >= 2 || degree[e.b] >= 2 {
                let full = degree[e.a] >= 2 ? names[e.a] : names[e.b]
                steps.append(SolverStep(
                    "Skip \(label): \(full) already has two connections.",
                    edges: chosen,
                    removed: [e],
                    focus: [e.a, e.b],
                    length: total
                ))
                continue
            }

            if components.find(e.a) == components.find(e.b) && chosen.count < n - 1 {
                steps.append(SolverStep(
                    "Skip \(label): it would close a loop before all cities are included.",
                    edges: chosen,
                    removed: [e],
                    focus: [e.a, e.b],
                    length: total
                ))
                continue
            }

            components.union(e.a, e.b)
            degree[e.a] += 1
            degree[e.b] += 1
            chosen.append(e)
            total += m[e.a, e.b]

            let note = chosen.count == n
                ? "This last connection closes the tour."
                : "\(chosen.count) of \(n) connections chosen."
            steps.append(SolverStep(
                "Add \(label). \(note)",
                edges: chosen,
                candidates: [e],
                focus: [e.a, e.b],
                length: total
            ))
        }

        let route = TourUtils.order(from: chosen, count: n)
        steps.append(SolverStep(
            "Every city now has exactly two connections, so together they form a complete tour.",
            path: route,
            closed: true,
            length: m.length(of: route)
        ))
        return steps
    }
}

// MARK: - Farthest Insertion

enum FarthestInsertion {
    static func run(_ m: DistanceMatrix, names: [String]) -> [SolverStep] {
        let n = m.count
        var a = 0
        var b = 1
        for i in 0..<n {
            for j in (i + 1)..<n where m[i, j] > m[a, b] {
                a = i
                b = j
            }
        }

        var tour = [a, b]
        var inTour = Array(repeating: false, count: n)
        inTour[a] = true
        inTour[b] = true
        var distanceToTour = (0..<n).map { min(m[$0, a], m[$0, b]) }

        var steps = [SolverStep(
            "Start with the two cities farthest apart: \(names[a]) and \(names[b]) (\(m[a, b].km)). Go there and back.",
            path: tour,
            closed: true,
            focus: [a, b],
            length: m.length(of: tour)
        )]

        while tour.count < n {
            var k = -1
            for c in 0..<n where !inTour[c] {
                if k == -1 || distanceToTour[c] > distanceToTour[k] { k = c }
            }
            var nearest = tour[0]
            for t in tour where m[k, t] < m[k, nearest] { nearest = t }

            steps.append(SolverStep(
                "\(names[k]) is the city farthest from the current tour (\(distanceToTour[k].km) to \(names[nearest])). It's inserted next.",
                path: tour,
                closed: true,
                candidates: [Edge(k, nearest)],
                focus: [k],
                length: m.length(of: tour)
            ))

            var bestPosition = 0
            var bestDelta = Double.infinity
            for p in 0..<tour.count {
                let i = tour[p]
                let j = tour[(p + 1) % tour.count]
                let delta = m[i, k] + m[k, j] - m[i, j]
                if delta < bestDelta {
                    bestDelta = delta
                    bestPosition = p
                }
            }
            let i = tour[bestPosition]
            let j = tour[(bestPosition + 1) % tour.count]

            steps.append(SolverStep(
                "The cheapest spot is between \(names[i]) and \(names[j]): replacing that connection with the detour via \(names[k]) adds only \(bestDelta.km).",
                path: tour,
                closed: true,
                candidates: [Edge(i, k), Edge(k, j)],
                removed: [Edge(i, j)],
                focus: [k],
                length: m.length(of: tour)
            ))

            tour.insert(k, at: bestPosition + 1)
            inTour[k] = true
            for c in 0..<n where !inTour[c] {
                distanceToTour[c] = min(distanceToTour[c], m[c, k])
            }
        }

        steps.append(SolverStep(
            "All \(n) cities are inserted. Because the outline came first, the tour has few awkward detours.",
            path: tour,
            closed: true,
            length: m.length(of: tour)
        ))
        return steps
    }
}
