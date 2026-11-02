# TSP Explorer

An iPadOS app that shows step by step how different algorithms solve the
Traveling Salesman Problem on real cities, drawn on Apple Maps (MapKit).

## Requirements

- A Mac with **Xcode 16 or newer**
- iPadOS **17** or newer (iPad Simulator or a real iPad)

## Open and run

1. Clone the repository (or unzip the folder) and double-click `TSPExplorer.xcodeproj`.
2. In the toolbar at the top of Xcode, choose an iPad simulator (e.g. *iPad Pro 13-inch*).
3. Press **⌘R**.

**On a real iPad:** select the *TSPExplorer* target → *Signing & Capabilities* →
choose your Apple ID as the **Team**, and change the **Bundle Identifier**
to something unique (e.g. `com.yourname.TSPExplorer`).

> If Xcode can't open the project for some reason: create a new
> *iOS App* project (SwiftUI) called `TSPExplorer`, delete its
> `ContentView.swift` and `TSPExplorerApp.swift`, and drag the contents of
> the `TSPExplorer/` folder into it. Set the deployment target to iPadOS 17.

## Using the app

The app is built as a presentation: a full-screen map and one card at the
bottom that controls everything. It walks through the chapters in order:

**Concorde** (the reference) → Nearest Neighbor → Greedy Edge → Farthest
Insertion → MST Double Tree → 2-Opt → Simulated Annealing → Ant Colony →
Branch & Bound → **Results**

| Where | What |
|---|---|
| **Back / Next** (bottom of the card) | Previous / next algorithm; algorithms that can't handle the number of cities (Branch & Bound above 12) are skipped. After the last one, Next shows the results, and on the results it starts over |
| ⓘ (top right of the card) | How the algorithm works, its running time, and the map legend |
| ⚙︎ (top right of the screen) | Language (English / Deutsch), region, number of cities (quick picks: 10 · 20 · All), add *any* city via search, show/hide names |
| Play / ◀︎ ▶︎ / slider | Play the animation, step through it, or scrub |
| Speed menu | 0.5× – 10× |
| Results | Every algorithm ranked against Concorde's optimum. Tap one to see its tour on the map |
| Tap a city on the map | Leave it out of (or add it back to) the tour |

Keyboard or presentation clicker: **Space** play/pause, **← →** step; at the
end of an animation **→** moves on to the next algorithm, so → alone drives the
whole talk. **⌘← ⌘→** = Back / Next at any time.

**Map colours:** blue = tour, orange = being considered / just added,
red dashed = rejected or removed, gray dashed = best tour so far,
faint blue = pheromone (Ant Colony) or spanning tree (MST).

## Algorithms

| Algorithm | Type | Idea |
|---|---|---|
| Nearest Neighbor | Construction | Always go to the closest unvisited city |
| Greedy Edge | Construction | Add shortest connections first, avoid degree 3 and early loops |
| Farthest Insertion | Construction | Insert the farthest city at its cheapest position |
| MST Double Tree | Approximation | Walk around a minimum spanning tree with shortcuts (≤ 2× optimal) |
| 2-Opt | Local search | Swap pairs of connections while it makes the tour shorter |
| Simulated Annealing | Metaheuristic | Random 2-opt moves; accept worse tours with probability e^(−Δ/T) |
| Ant Colony | Metaheuristic | Ants follow pheromone × (1/distance)³; good edges get reinforced |
| Branch & Bound | Exact | Search all tours, prune branches with a lower bound (≤ 12 cities) |
| Concorde | Exact | The real Concorde solver, run ahead of time on a Mac; results bundled (preset cities) |

Distances are great-circle distances (haversine formula, Earth radius 6371 km),
and the lines on the map are drawn as geodesics, so they follow the
curvature of the Earth.

Randomised algorithms use a fixed seed, so the same cities always give the
same animation, which helps for presentations.

## Project structure

```
TSPExplorer/
├── TSPExplorerApp.swift        App entry point
├── Model/
│   ├── City.swift              City type + real city data (4 regions)
│   ├── DistanceMatrix.swift    Haversine distances, tour length
│   ├── SolverStep.swift        One animation frame + helpers
│   ├── ExplorerModel.swift     App state, playback, camera
│   └── Localization.swift      English / German texts
├── Algorithms/                 One file per family; every algorithm
│   └── …                       returns a list of SolverSteps
└── Views/
    ├── ContentView.swift       Full-screen map, the card, settings button
    ├── TourMap.swift           MapKit drawing
    ├── ControlPanel.swift      The card: playback, Back / Next
    ├── ResultsView.swift       Last chapter: ranking and takeaways
    ├── AlgorithmInfoView.swift "How it works" popover
    └── SettingsView.swift      Language, city selection + MapKit search
```

**Adding an algorithm:** add a case to `Algorithm` in `Algorithm.swift`, fill in
its texts, and return a list of `SolverStep`s from `solve(_:names:)`. The map and
controls work automatically.

## Concorde

Concorde (Applegate, Bixby, Chvátal & Cook) is the record-holding exact TSP
solver. It's written in C and needs the QSopt LP solver, which can't run on
iPadOS, so the app doesn't run it live. Instead it is run **ahead of time on a
Mac** and its results are bundled into the app as
`TSPExplorer/concorde_results.json`.

**The app works out of the box.** `concorde_results.json` is in the
repository, so you don't need Concorde to build or run the app. You only need
it to regenerate the results, e.g. after changing the preset cities.

### Concorde and QSopt are not included

Concorde and the QSopt LP solver are free for academic research use only and
may not be redistributed, so this repository contains neither their source
code nor their binaries (`Concorde/build/` is in `.gitignore`). The build
script downloads them from their sources:

| Component | Source | License |
|---|---|---|
| Concorde 03.12.19 | [math.uwaterloo.ca/tsp/concorde](https://www.math.uwaterloo.ca/tsp/concorde.html) (cloned from the mirror [github.com/matthelb/concorde](https://github.com/matthelb/concorde)) | Academic research use; other uses: contact the authors |
| QSopt (macOS x86_64) | [math.uwaterloo.ca/~bico/qsopt](https://www.math.uwaterloo.ca/~bico/qsopt/) | Free for research use |

By running the script you obtain these yourself and accept their terms.

### Regenerating the results

Requirements: Xcode Command Line Tools (`xcode-select --install`), Python 3,
and on Apple Silicon Rosetta 2 (`softwareupdate --install-rosetta`).

From the project folder in Terminal:

```
bash Concorde/build_concorde.sh          # clones Concorde, downloads QSopt into Concorde/build/, compiles
python3 Concorde/generate_results.py     # runs Concorde on every preset, writes the JSON
```

Then rebuild the app in Xcode. The JSON is picked up automatically.

- Results exist for every preset region and city count (3 … all) **with no
  cities tapped off or added**. For other city sets the app says there's no
  Concorde result.
- Distances are the app's haversine distances rounded to whole metres
  (Concorde needs integers).
- On Apple Silicon, Concorde is built for x86_64 and runs under Rosetta 2,
  because QSopt is only published for Intel Macs.
- The animation shows Concorde's own steps, each from a separate Concorde run:
  the Lin–Kernighan tour (upper bound), then the LP lower bound after each
  cutting-plane stage (2-matching → subtour cuts → blossoms → full cutting
  loop), drawn on the map, until the bounds meet. A bar shows the gap
  closing. Below 10 cities Concorde uses Held–Karp instead. Europe with
  20 cities shows all four stages.
- **Finale:** ⚙︎ → Germany → Quick pick "All 100". Concorde proves the 100-city
  tour optimal in under a tenth of a second, out of about 10¹⁵⁵ possible tours.
- Every other algorithm is measured against Concorde's optimum: the
  distance shows "+x% vs optimal", and the Results chapter ranks everything
  against it, with the optimal tour dashed on the map.

If you mention Concorde in your project, credit its authors and see
math.uwaterloo.ca/tsp/concorde.
