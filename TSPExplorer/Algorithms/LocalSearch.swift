import Foundation

// MARK: - 2-Opt

enum TwoOpt {
    static func run(_ m: DistanceMatrix, names: [String], seed: UInt64 = 7) -> [SolverStep] {
        let n = m.count
        var rng = SeededGenerator(seed: seed)
        var tour = Array(0..<n).shuffled(using: &rng)
        var steps = [SolverStep(
            "Start from a random tour. It's deliberately bad, so you can watch 2-opt untangle it.",
            path: tour,
            closed: true,
            length: m.length(of: tour)
        )]

        var improved = true
        var swaps = 0
        let maxSwaps = 500

        while improved && swaps < maxSwaps {
            improved = false
            search: for i in 0..<(n - 1) {
                for j in (i + 2)..<n {
                    if i == 0 && j == n - 1 { continue }
                    let a = tour[i]
                    let b = tour[i + 1]
                    let c = tour[j]
                    let d = tour[(j + 1) % n]
                    let delta = m[a, c] + m[b, d] - m[a, b] - m[c, d]
                    guard delta < -1e-7 else { continue }

                    steps.append(SolverStep(
                        "Remove \(names[a])–\(names[b]) and \(names[c])–\(names[d]). Reconnecting as \(names[a])–\(names[c]) and \(names[b])–\(names[d]) saves \((-delta).km).",
                        path: tour,
                        closed: true,
                        candidates: [Edge(a, c), Edge(b, d)],
                        removed: [Edge(a, b), Edge(c, d)],
                        focus: [a, b, c, d],
                        length: m.length(of: tour)
                    ))

                    tour[(i + 1)...j].reverse()
                    swaps += 1
                    improved = true

                    steps.append(SolverStep(
                        "Swap \(swaps) done. The part between \(names[b]) and \(names[c]) is now travelled in reverse.",
                        path: tour,
                        closed: true,
                        candidates: [Edge(a, c), Edge(b, d)],
                        length: m.length(of: tour)
                    ))
                    break search
                }
            }
        }

        steps.append(SolverStep(
            "No pair of connections can be swapped to shorten the tour any more. This is a 2-opt local optimum: good, but not necessarily the best possible tour.",
            path: tour,
            closed: true,
            length: m.length(of: tour)
        ))
        return steps
    }
}

// MARK: - Simulated Annealing

enum SimulatedAnnealing {
    static func run(_ m: DistanceMatrix, names: [String], seed: UInt64 = 42) -> [SolverStep] {
        let n = m.count
        var rng = SeededGenerator(seed: seed)
        var tour = Array(0..<n).shuffled(using: &rng)
        var current = m.length(of: tour)
        var best = tour
        var bestLength = current

        let startTemperature = max(current / Double(n), 1)
        let endTemperature = startTemperature * 0.0005
        let iterations = 30_000 + n * 3_000
        let cooling = pow(endTemperature / startTemperature, 1.0 / Double(iterations))
        let frames = 220
        let frameEvery = max(1, iterations / frames)

        var temperature = startTemperature
        var uphill = 0
        var downhill = 0

        var steps = [SolverStep(
            "Start from a random tour at temperature \(Int(startTemperature)). While it's hot, even changes that make the tour longer are often accepted.",
            path: tour,
            closed: true,
            length: current
        )]

        for iteration in 1...iterations {
            var i = Int.random(in: 0..<n, using: &rng)
            var j = Int.random(in: 0..<n, using: &rng)
            if i > j { swap(&i, &j) }

            if i != j && !(i == 0 && j == n - 1) {
                // Reversing tour[i...j] replaces a–b and c–d with a–c and b–d.
                let a = tour[(i - 1 + n) % n]
                let b = tour[i]
                let c = tour[j]
                let d = tour[(j + 1) % n]
                let delta = m[a, c] + m[b, d] - m[a, b] - m[c, d]
                if delta <= 0 || Double.random(in: 0..<1, using: &rng) < exp(-delta / temperature) {
                    tour[i...j].reverse()
                    current += delta
                    if delta > 1e-9 { uphill += 1 } else if delta < -1e-9 { downhill += 1 }
                    if current < bestLength - 1e-9 {
                        bestLength = current
                        best = tour
                    }
                }
            }

            temperature *= cooling

            if iteration % frameEvery == 0 {
                current = m.length(of: tour)
                let mood: String
                if uphill > downhill / 2 {
                    mood = "Still hot: many worse tours are accepted, so the search roams freely."
                } else if uphill > 0 {
                    mood = "Cooling: worse tours are accepted less and less often."
                } else {
                    mood = "Nearly frozen: only improvements get through now."
                }
                steps.append(SolverStep(
                    "Temperature \(Int(temperature.rounded())) · \(downhill) improvements, \(uphill) uphill moves since the last frame. \(mood) Dashed: best tour so far.",
                    path: tour,
                    closed: true,
                    ghost: best,
                    length: current
                ))
                uphill = 0
                downhill = 0
            }
        }

        steps.append(SolverStep(
            "Frozen. The best tour seen during the whole run: \(bestLength.km).",
            path: best,
            closed: true,
            length: bestLength
        ))
        return steps
    }
}
