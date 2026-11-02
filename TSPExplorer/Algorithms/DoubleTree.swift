import Foundation

/// MST-based 2-approximation ("double tree"): Prim's algorithm, then a
/// depth-first walk around the tree with shortcuts.
enum DoubleTree {
    static func run(_ m: DistanceMatrix, names: [String]) -> [SolverStep] {
        let n = m.count
        var steps: [SolverStep] = []

        // Phase 1: Prim's minimum spanning tree.
        var inTree = Array(repeating: false, count: n)
        inTree[0] = true
        var cheapest = (0..<n).map { m[0, $0] }
        var parent = Array(repeating: 0, count: n)
        var tree: [Edge] = []
        var treeLength = 0.0

        steps.append(SolverStep(
            "Phase 1: build a minimum spanning tree, the cheapest network that connects every city. Start the tree at \(names[0]).",
            focus: [0],
            length: 0
        ))

        for _ in 1..<n {
            var k = -1
            for c in 0..<n where !inTree[c] {
                if k == -1 || cheapest[c] < cheapest[k] { k = c }
            }
            let from = parent[k]
            let edge = Edge(from, k)
            inTree[k] = true
            tree.append(edge)
            treeLength += m[from, k]
            for c in 0..<n where !inTree[c] && m[k, c] < cheapest[c] {
                cheapest[c] = m[k, c]
                parent[c] = k
            }
            steps.append(SolverStep(
                "The shortest connection from the tree to a new city is \(names[from])–\(names[k]) (\(m[from, k].km)). Add it.",
                edges: tree,
                candidates: [edge],
                focus: [k],
                length: treeLength
            ))
        }

        let treeShade = tree.map { WeightedEdge(edge: $0, weight: 0.35) }
        steps.append(SolverStep(
            "The tree is complete: \(treeLength.km). Any tour minus one connection is a spanning tree, so the optimal tour must be longer than this. That's our lower bound.",
            edges: tree,
            length: treeLength
        ))

        // Phase 2: depth-first walk with shortcuts.
        var adjacency = Array(repeating: [Int](), count: n)
        for e in tree {
            adjacency[e.a].append(e.b)
            adjacency[e.b].append(e.a)
        }
        var order: [Int] = []
        var seen = Array(repeating: false, count: n)
        var stack = [0]
        while let v = stack.popLast() {
            if seen[v] { continue }
            seen[v] = true
            order.append(v)
            // Push farthest first so the nearest child is visited first.
            let children = adjacency[v].filter { !seen[$0] }.sorted { m[v, $0] > m[v, $1] }
            stack.append(contentsOf: children)
        }

        let treeEdges = Set(tree)
        steps.append(SolverStep(
            "Phase 2: walk around the tree, starting at \(names[0]). Walking every branch out and back would use each connection twice, at most 2× the tree.",
            path: [order[0]],
            weighted: treeShade,
            focus: [order[0]],
            length: 0
        ))

        for index in 1..<order.count {
            let previous = order[index - 1]
            let current = order[index]
            let route = Array(order[0...index])
            let message = treeEdges.contains(Edge(previous, current))
                ? "Follow the tree from \(names[previous]) to \(names[current])."
                : "Shortcut: instead of walking back through cities already visited, go straight from \(names[previous]) to \(names[current]). A direct route is never longer."
            steps.append(SolverStep(
                message,
                path: route,
                candidates: [Edge(previous, current)],
                weighted: treeShade,
                focus: [current],
                length: m.length(of: route, closed: false)
            ))
        }

        let tourLength = m.length(of: order)
        let ratio = (tourLength / treeLength).formatted(.number.precision(.fractionLength(2)))
        steps.append(SolverStep(
            "Close the tour: \(tourLength.km), which is \(ratio)× the tree. The guarantee says this can never exceed 2× the optimal tour.",
            path: order,
            closed: true,
            weighted: treeShade,
            length: tourLength
        ))
        return steps
    }
}
