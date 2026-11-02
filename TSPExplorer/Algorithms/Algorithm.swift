import Foundation

enum AlgorithmCategory: String, CaseIterable, Identifiable {
    case construction, approximation, improvement, metaheuristic, exact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .construction: return tr("Construction Heuristics", "Konstruktionsheuristiken")
        case .approximation: return tr("Approximation", "Approximation")
        case .improvement: return tr("Local Search", "Lokale Suche")
        case .metaheuristic: return tr("Metaheuristics", "Metaheuristiken")
        case .exact: return tr("Exact", "Exakt")
        }
    }
}

/// Every algorithm the app can visualise, with the texts shown in the app.
/// The order is the order of the presentation: Concorde first, as the reference.
enum Algorithm: String, CaseIterable, Identifiable {
    case concorde
    case nearestNeighbor
    case greedyEdge
    case farthestInsertion
    case doubleTree
    case twoOpt
    case simulatedAnnealing
    case antColony
    case branchAndBound

    var id: String { rawValue }

    var category: AlgorithmCategory {
        switch self {
        case .nearestNeighbor, .greedyEdge, .farthestInsertion: return .construction
        case .doubleTree: return .approximation
        case .twoOpt: return .improvement
        case .simulatedAnnealing, .antColony: return .metaheuristic
        case .branchAndBound, .concorde: return .exact
        }
    }

    /// Exact search grows factorially, so it is limited to small instances.
    var maxCities: Int? {
        self == .branchAndBound ? BranchAndBound.maxCities : nil
    }

    func solve(_ matrix: DistanceMatrix, cities: [City]) -> [SolverStep] {
        let names = cities.map(\.name)
        switch self {
        case .nearestNeighbor: return NearestNeighbor.run(matrix, names: names)
        case .greedyEdge: return GreedyEdge.run(matrix, names: names)
        case .farthestInsertion: return FarthestInsertion.run(matrix, names: names)
        case .doubleTree: return DoubleTree.run(matrix, names: names)
        case .twoOpt: return TwoOpt.run(matrix, names: names)
        case .simulatedAnnealing: return SimulatedAnnealing.run(matrix, names: names)
        case .antColony: return AntColony.run(matrix, names: names)
        case .branchAndBound: return BranchAndBound.run(matrix, names: names)
        case .concorde: return Concorde.run(matrix, cities: cities)
        }
    }

    // MARK: Texts (English and German)

    var title: String {
        switch self {
        case .concorde: return "Concorde"
        case .nearestNeighbor: return tr("Nearest Neighbor", "Nächster Nachbar")
        case .greedyEdge: return tr("Greedy Edge", "Greedy-Kanten")
        case .farthestInsertion: return "Farthest Insertion"
        case .doubleTree: return tr("MST Double Tree", "MST-Doppelbaum")
        case .twoOpt: return "2-Opt"
        case .simulatedAnnealing: return "Simulated Annealing"
        case .antColony: return tr("Ant Colony", "Ameisenkolonie")
        case .branchAndBound: return "Branch & Bound"
        }
    }

    var symbol: String {
        switch self {
        case .concorde: return "airplane"
        case .nearestNeighbor: return "location.north.line"
        case .greedyEdge: return "line.3.horizontal.decrease"
        case .farthestInsertion: return "arrow.up.left.and.arrow.down.right"
        case .doubleTree: return "point.3.connected.trianglepath.dotted"
        case .twoOpt: return "scissors"
        case .simulatedAnnealing: return "thermometer.medium"
        case .antColony: return "ant"
        case .branchAndBound: return "arrow.triangle.branch"
        }
    }

    var summary: String {
        switch self {
        case .concorde:
            return tr(
                "Concorde by Applegate, Bixby, Chvátal and Cook has solved instances with over 85,000 cities to proven optimality. It squeezes the optimum between a heuristic tour from above and a linear-programming bound from below until the two meet. It can't run on an iPad, so its results for the preset cities were computed ahead of time on a Mac and bundled into the app.",
                "Concorde von Applegate, Bixby, Chvátal und Cook hat Probleme mit über 85.000 Städten beweisbar optimal gelöst. Es grenzt das Optimum von oben durch eine heuristische Tour und von unten durch eine Schranke aus der linearen Optimierung ein, bis sich beide treffen. Auf dem iPad läuft es nicht, daher wurden die Ergebnisse für die vorgegebenen Städte vorab auf einem Mac berechnet und in die App eingebaut."
            )
        case .nearestNeighbor:
            return tr(
                "The rule anyone would invent: from where you are, travel to the closest city you haven't visited yet. It's fast and simple, but early greedy choices can force long detours at the end.",
                "Die Regel, auf die jeder kommt: Fahre von deinem Standort zur nächstgelegenen Stadt, die du noch nicht besucht hast. Das ist schnell und einfach, aber gierige Entscheidungen am Anfang erzwingen am Ende oft lange Umwege."
            )
        case .greedyEdge:
            return tr(
                "Instead of walking a route, this method collects the tour's pieces: it takes the shortest connections first and rejects one only if a city would get three connections or a loop would close too early.",
                "Statt eine Route abzulaufen, sammelt dieses Verfahren die Teile der Tour: Es nimmt die kürzesten Verbindungen zuerst und lehnt eine nur ab, wenn eine Stadt drei Verbindungen bekäme oder sich zu früh ein Kreis schließen würde."
            )
        case .farthestInsertion:
            return tr(
                "Starts with the two cities farthest apart and keeps inserting the city that is farthest from the current tour, at the spot where it adds the least distance. Sketching the outline first gives well-shaped tours.",
                "Beginnt mit den zwei am weitesten entfernten Städten und fügt immer die Stadt ein, die am weitesten von der aktuellen Tour entfernt ist, und zwar dort, wo sie am wenigsten Strecke hinzufügt. Weil zuerst der Umriss entsteht, werden die Touren gut geformt."
            )
        case .doubleTree:
            return tr(
                "Builds a minimum spanning tree, the cheapest network connecting every city, and walks around it, skipping cities it has already seen. Because the tree is shorter than any tour, the result is provably at most twice the optimum.",
                "Baut einen minimalen Spannbaum, das günstigste Netz, das alle Städte verbindet, und läuft um ihn herum, wobei bereits besuchte Städte übersprungen werden. Da der Baum kürzer als jede Tour ist, ist das Ergebnis beweisbar höchstens doppelt so lang wie das Optimum."
            )
        case .twoOpt:
            return tr(
                "A local search that improves an existing tour. It looks for two connections that can be reconnected the other way round to make the tour shorter. On a flat map, this removes every crossing.",
                "Eine lokale Suche, die eine bestehende Tour verbessert. Sie sucht zwei Verbindungen, die andersherum verbunden die Tour verkürzen. Auf einer flachen Karte verschwinden dadurch alle Kreuzungen."
            )
        case .simulatedAnnealing:
            return tr(
                "Inspired by slowly cooling metal. It tries random changes and always accepts improvements, but also accepts worse tours with a probability that shrinks as the temperature falls. That lets it escape local optima early on.",
                "Inspiriert vom langsamen Abkühlen von Metall. Es probiert zufällige Änderungen aus und nimmt Verbesserungen immer an, aber auch schlechtere Touren mit einer Wahrscheinlichkeit, die mit sinkender Temperatur kleiner wird. So entkommt es anfangs lokalen Optima."
            )
        case .antColony:
            return tr(
                "Simulated ants build tours, preferring nearby cities and connections with lots of pheromone. Pheromone evaporates every round and short tours deposit more, so good connections get reinforced, like real ants finding the shortest path to food.",
                "Simulierte Ameisen bauen Touren und bevorzugen nahe Städte und Verbindungen mit viel Pheromon. Pheromon verdunstet jede Runde und kurze Touren hinterlassen mehr davon, sodass gute Verbindungen verstärkt werden, wie bei echten Ameisen auf dem kürzesten Weg zum Futter."
            )
        case .branchAndBound:
            return tr(
                "Explores all possible tours as a decision tree, but discards whole branches as soon as a lower bound shows they can't beat the best tour so far. It always finds the true optimum, though the running time can still grow factorially.",
                "Durchsucht alle möglichen Touren als Entscheidungsbaum, verwirft aber ganze Äste, sobald eine untere Schranke zeigt, dass sie die bisher beste Tour nicht schlagen können. Es findet immer das echte Optimum, die Laufzeit kann aber trotzdem faktoriell wachsen."
            )
        }
    }

    var howItWorks: [String] {
        switch self {
        case .concorde:
            return [
                tr("Find a very good tour with Lin–Kernighan. That's the upper bound.",
                   "Mit Lin–Kernighan eine sehr gute Tour finden. Das ist die obere Schranke."),
                tr("Solve a linear program in which each connection may be used fractionally. Its value is a lower bound.",
                   "Ein lineares Programm lösen, in dem jede Verbindung auch nur teilweise genutzt werden darf. Sein Wert ist eine untere Schranke."),
                tr("Add cutting planes, inequalities every real tour satisfies but the fractional solution breaks, to raise the bound.",
                   "Schnittebenen hinzufügen: Ungleichungen, die jede echte Tour erfüllt, die gebrochene Lösung aber verletzt. Das hebt die Schranke an."),
                tr("If the bounds still differ, branch on a connection (use it or not) and repeat in each half.",
                   "Liegen die Schranken noch auseinander, nach einer Verbindung verzweigen (nutzen oder nicht) und in beiden Hälften wiederholen."),
                tr("When the lower bound reaches the best tour, it's proven optimal. (Below 10 cities Concorde uses Held–Karp instead.)",
                   "Erreicht die untere Schranke die beste Tour, ist sie beweisbar optimal. (Unter 10 Städten nutzt Concorde stattdessen Held–Karp.)"),
            ]
        case .nearestNeighbor:
            return [
                tr("Pick a start city.", "Eine Startstadt wählen."),
                tr("Compare the distances to all cities not yet visited.", "Die Entfernungen zu allen noch nicht besuchten Städten vergleichen."),
                tr("Travel to the closest one and repeat.", "Zur nächstgelegenen fahren und wiederholen."),
                tr("When every city is visited, return to the start.", "Sind alle Städte besucht, zum Start zurückkehren."),
            ]
        case .greedyEdge:
            return [
                tr("List every possible connection and sort them by length.", "Alle möglichen Verbindungen auflisten und nach Länge sortieren."),
                tr("Take the next shortest connection.", "Die nächstkürzere Verbindung nehmen."),
                tr("Reject it if a city would get a third connection, or if it would close a loop before all cities are included.",
                   "Sie ablehnen, wenn eine Stadt eine dritte Verbindung bekäme oder sich ein Kreis schließen würde, bevor alle Städte dabei sind."),
                tr("Stop when every city has exactly two connections.", "Aufhören, wenn jede Stadt genau zwei Verbindungen hat."),
            ]
        case .farthestInsertion:
            return [
                tr("Start with a round trip between the two most distant cities.", "Mit einer Rundreise zwischen den zwei am weitesten entfernten Städten beginnen."),
                tr("Find the city farthest from the current tour.", "Die Stadt finden, die am weitesten von der aktuellen Tour entfernt ist."),
                tr("Try inserting it between every pair of neighbouring tour cities and choose the cheapest spot.",
                   "Sie probeweise zwischen je zwei benachbarte Tourstädte einfügen und die günstigste Stelle wählen."),
                tr("Repeat until every city is part of the tour.", "Wiederholen, bis jede Stadt Teil der Tour ist."),
            ]
        case .doubleTree:
            return [
                tr("Build a minimum spanning tree (Prim): repeatedly add the shortest connection that reaches a new city.",
                   "Einen minimalen Spannbaum bauen (Prim): immer die kürzeste Verbindung hinzufügen, die eine neue Stadt erreicht."),
                tr("Walk around the tree depth-first. This would use every connection twice.",
                   "Den Baum in Tiefensuche umrunden. Dabei würde jede Verbindung zweimal benutzt."),
                tr("Whenever the walk would revisit a city, take a shortcut straight to the next new one.",
                   "Würde der Weg eine Stadt erneut besuchen, direkt zur nächsten neuen Stadt abkürzen."),
                tr("Close the tour. Shortcuts never make it longer, so it's at most 2× the tree, and the tree is shorter than the optimal tour.",
                   "Die Tour schließen. Abkürzungen machen sie nie länger, also ist sie höchstens doppelt so lang wie der Baum, und der Baum ist kürzer als die optimale Tour."),
            ]
        case .twoOpt:
            return [
                tr("Start with any tour (here: a random one).", "Mit irgendeiner Tour beginnen (hier: einer zufälligen)."),
                tr("For two connections A–B and C–D, check whether A–C plus B–D is shorter.", "Für zwei Verbindungen A–B und C–D prüfen, ob A–C plus B–D kürzer ist."),
                tr("If so, swap them by reversing the part of the tour between B and C.", "Wenn ja, tauschen, indem der Tourabschnitt zwischen B und C umgedreht wird."),
                tr("Repeat until no swap helps. The result is a local optimum.", "Wiederholen, bis kein Tausch mehr hilft. Das Ergebnis ist ein lokales Optimum."),
            ]
        case .simulatedAnnealing:
            return [
                tr("Start with a random tour and a high temperature T.", "Mit einer zufälligen Tour und einer hohen Temperatur T beginnen."),
                tr("Pick a random section of the tour and consider reversing it.", "Einen zufälligen Abschnitt der Tour wählen und überlegen, ihn umzudrehen."),
                tr("If that's shorter, accept. If it's longer by Δ, accept with probability e^(−Δ/T).",
                   "Ist das kürzer, annehmen. Ist es um Δ länger, mit Wahrscheinlichkeit e^(−Δ/T) annehmen."),
                tr("Lower T a little and repeat. Once cold, only improvements get through.",
                   "T etwas senken und wiederholen. Ist es kalt, kommen nur noch Verbesserungen durch."),
            ]
        case .antColony:
            return [
                tr("Every ant starts in a random city.", "Jede Ameise startet in einer zufälligen Stadt."),
                tr("It picks the next city with probability ∝ pheromone × (1/distance)³.", "Sie wählt die nächste Stadt mit Wahrscheinlichkeit ∝ Pheromon × (1/Entfernung)³."),
                tr("After all ants finish, 40% of all pheromone evaporates.", "Wenn alle Ameisen fertig sind, verdunsten 40 % des Pheromons."),
                tr("Each ant deposits pheromone on its tour, more for shorter tours. Repeat.", "Jede Ameise hinterlässt Pheromon auf ihrer Tour, mehr bei kürzeren Touren. Wiederholen."),
            ]
        case .branchAndBound:
            return [
                tr("Find a quick tour (nearest neighbor) as the bar to beat.", "Eine schnelle Tour (nächster Nachbar) als Messlatte finden."),
                tr("Extend a partial route one city at a time, nearest cities first.", "Eine Teilroute Stadt für Stadt verlängern, nächste Städte zuerst."),
                tr("Compute a lower bound: the route so far plus the cheapest possible way to leave every remaining city.",
                   "Eine untere Schranke berechnen: die bisherige Route plus der günstigste Weg aus jeder verbleibenden Stadt heraus."),
                tr("If that bound can't beat the best tour, prune the whole branch.", "Kann diese Schranke die beste Tour nicht schlagen, den ganzen Ast abschneiden."),
                tr("When no branches are left, the best tour is proven optimal.", "Sind keine Äste mehr übrig, ist die beste Tour beweisbar optimal."),
            ]
        }
    }

    var complexity: String {
        switch self {
        case .concorde: return tr("Exponential worst case, fast in practice", "Im schlimmsten Fall exponentiell, in der Praxis schnell")
        case .nearestNeighbor: return "O(n²)"
        case .greedyEdge: return "O(n² log n)"
        case .farthestInsertion: return "O(n²)"
        case .doubleTree: return "O(n²)"
        case .twoOpt: return tr("O(n²) per pass", "O(n²) pro Durchlauf")
        case .simulatedAnnealing: return tr("Set by the cooling schedule", "Hängt vom Abkühlplan ab")
        case .antColony: return tr("O(rounds · ants · n²)", "O(Runden · Ameisen · n²)")
        case .branchAndBound: return tr("O(n!) worst case", "O(n!) im schlimmsten Fall")
        }
    }

    var quality: String {
        switch self {
        case .concorde, .branchAndBound: return tr("Optimal", "Optimal")
        case .nearestNeighbor: return tr("Typically ~25% above optimal", "Meist ~25 % über dem Optimum")
        case .greedyEdge: return tr("Typically 15–20% above optimal", "Meist 15–20 % über dem Optimum")
        case .farthestInsertion: return tr("Often within ~10% of optimal", "Oft innerhalb von ~10 % des Optimums")
        case .doubleTree: return tr("Guaranteed ≤ 2× optimal", "Garantiert ≤ 2× Optimum")
        case .twoOpt: return tr("Typically ~5% above optimal", "Meist ~5 % über dem Optimum")
        case .simulatedAnnealing: return tr("Often within a few percent", "Oft nur wenige Prozent darüber")
        case .antColony: return tr("Improves round by round", "Wird Runde für Runde besser")
        }
    }
}
