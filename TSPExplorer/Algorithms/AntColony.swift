import Foundation

/// Ant System (Dorigo): ants build tours probabilistically, guided by pheromone
/// and distance; pheromone evaporates and short tours reinforce their edges.
enum AntColony {
    static func run(_ m: DistanceMatrix, names: [String], seed: UInt64 = 2024) -> [SolverStep] {
        let n = m.count
        var rng = SeededGenerator(seed: seed)
        let beta = 3.0
        let evaporation = 0.4
        // One ant per city, but at most 40 so 100 cities stay quick.
        let ants = min(max(10, n), 40)
        let rounds = 40

        let referenceLength = max(m.length(of: NearestNeighbor.tour(m)), 1)
        var pheromone = Array(repeating: Double(ants) / referenceLength, count: n * n)
        var visibility = Array(repeating: 0.0, count: n * n)
        for i in 0..<n {
            for j in 0..<n where i != j {
                visibility[i * n + j] = pow(1 / max(m[i, j], 0.001), beta)
            }
        }

        var best: [Int] = []
        var bestLength = Double.infinity
        var trails: [WeightedEdge] = []

        var steps = [SolverStep(
            "\(ants) ants will each build a tour, \(rounds) rounds in a row. At first every connection has the same amount of pheromone, so only distance guides them."
        )]

        var options: [Int] = []
        var weights: [Double] = []
        options.reserveCapacity(n)
        weights.reserveCapacity(n)

        for round in 1...rounds {
            var tours: [[Int]] = []

            for ant in 0..<ants {
                let start = Int.random(in: 0..<n, using: &rng)
                var tour = [start]
                var visited = Array(repeating: false, count: n)
                visited[start] = true

                while tour.count < n {
                    let current = tour[tour.count - 1]
                    options.removeAll(keepingCapacity: true)
                    weights.removeAll(keepingCapacity: true)
                    var total = 0.0
                    for c in 0..<n where !visited[c] {
                        let w = pheromone[current * n + c] * visibility[current * n + c]
                        options.append(c)
                        weights.append(w)
                        total += w
                    }
                    var pick = Double.random(in: 0..<1, using: &rng) * total
                    var next = options[options.count - 1]
                    for (index, option) in options.enumerated() {
                        pick -= weights[index]
                        if pick <= 0 {
                            next = option
                            break
                        }
                    }

                    // Show the very first ant's decisions in detail.
                    if round == 1 && ant == 0 {
                        let strongest = max(weights.max() ?? 1, 1e-12)
                        let chance = total > 0 ? weights[options.firstIndex(of: next) ?? 0] / total * 100 : 0
                        let optionEdges = options.enumerated().map { index, option in
                            WeightedEdge(edge: Edge(current, option), weight: weights[index] / strongest)
                        }
                        steps.append(SolverStep(
                            "Ant 1 is in \(names[current]). Thicker lines are more attractive (close and lots of pheromone). It rolls the dice and picks \(names[next]) (\(Int(chance.rounded()))% chance).",
                            path: tour + [next],
                            candidates: [Edge(current, next)],
                            weighted: optionEdges,
                            focus: [next],
                            length: m.length(of: tour + [next], closed: false)
                        ))
                    }

                    tour.append(next)
                    visited[next] = true
                }
                tours.append(tour)
            }

            // Evaporate, then deposit pheromone proportional to tour quality.
            for k in 0..<pheromone.count { pheromone[k] *= (1 - evaporation) }
            var roundBest = tours[0]
            var roundBestLength = Double.infinity
            for tour in tours {
                let length = m.length(of: tour)
                if length < roundBestLength {
                    roundBestLength = length
                    roundBest = tour
                }
                let deposit = 1 / max(length, 1)
                for k in 0..<n {
                    let i = tour[k]
                    let j = tour[(k + 1) % n]
                    pheromone[i * n + j] += deposit
                    pheromone[j * n + i] += deposit
                }
            }
            let isNewBest = roundBestLength < bestLength - 1e-9
            if isNewBest {
                bestLength = roundBestLength
                best = roundBest
            }

            var strongest = 1e-12
            for i in 0..<n {
                for j in (i + 1)..<n { strongest = max(strongest, pheromone[i * n + j]) }
            }
            trails = []
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let w = pheromone[i * n + j] / strongest
                    if w > 0.06 { trails.append(WeightedEdge(edge: Edge(i, j), weight: w)) }
                }
            }

            let note = isNewBest ? "New best tour!" : "Best so far: \(bestLength.km)."
            steps.append(SolverStep(
                "Round \(round) of \(rounds): all \(ants) ants are done. 40% of the pheromone evaporates and short tours leave more behind, so thick trails mark popular connections. This round's best: \(roundBestLength.km). \(note)",
                path: roundBest,
                closed: true,
                weighted: trails,
                ghost: best,
                length: roundBestLength
            ))
        }

        steps.append(SolverStep(
            "After \(rounds) rounds the colony has converged on its favourite connections. Best tour: \(bestLength.km).",
            path: best,
            closed: true,
            weighted: trails,
            length: bestLength
        ))
        return steps
    }
}
