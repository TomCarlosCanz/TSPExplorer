#!/usr/bin/env python3
"""Runs Concorde on every preset city set and bundles the results into the app.

For every region in TSPExplorer/Model/City.swift and every city count the app
offers (3 … all cities, no cities tapped off), this script

  1. writes a TSPLIB file with the exact haversine distances the app uses
     (whole metres, because Concorde works with integer distances; below 10
     cities a coarser unit, because Concorde's Held–Karp code limits edge length),
  2. runs Concorde's Lin–Kernighan heuristic (linkern) for its starting tour,
  3. runs Concorde's cutting-plane stages one at a time (2-matching, subtour
     cuts, + blossoms, all cuts) and keeps each stage's LP bound and solution,
     so the app can show the lower bound climbing towards the optimum,
  4. runs Concorde itself for the proven-optimal tour,

and writes everything to TSPExplorer/concorde_results.json, which Xcode
bundles automatically.

Run build_concorde.sh first.  Usage:  python3 Concorde/generate_results.py
"""

import json
import math
import re
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
CITY_FILE = ROOT / "TSPExplorer" / "Model" / "City.swift"
OUTPUT = ROOT / "TSPExplorer" / "concorde_results.json"
CONCORDE = HERE / "build" / "concorde" / "TSP" / "concorde"
LINKERN = HERE / "build" / "concorde" / "LINKERN" / "linkern"

# Concorde skips LK and the LP below this size and uses Held–Karp instead.
LP_MIN_CITIES = 10
# Concorde's Held–Karp code rejects edges longer than 2^15 units.
HELD_KARP_MAX_EDGE = 32000
# Cutting-plane stages, weakest first: (name, concorde options). The last one is
# the normal full run; -X saves the LP solution at the end of each stage.
LP_STAGES = [
    ("matching", ["-i"]),   # degree + blossom inequalities: separate loops
    ("subtour", ["-I"]),    # degree + subtour inequalities
    ("blossom", ["-w"]),    # subtours + simple blossoms
    ("root", []),           # Concorde's full root cutting loop
]


def load_regions():
    """Parses `static let <region>: [City] = [ City(...), … ]` from City.swift."""
    source = CITY_FILE.read_text(encoding="utf-8")
    regions = {}
    for block in re.finditer(r"static let (\w+): \[City\] = \[(.*?)\n    \]", source, re.S):
        cities = [
            (name, country, float(lat), float(lon))
            for name, country, lat, lon in re.findall(
                r'City\("([^"]*)", "([^"]*)", (-?[\d.]+), (-?[\d.]+)\)', block.group(2)
            )
        ]
        regions[block.group(1)] = cities
    if not regions:
        sys.exit(f"No cities found in {CITY_FILE}")
    return regions


def haversine(a, b):
    """Same formula as DistanceMatrix.haversine in the app (km)."""
    radius = 6371.0
    lat1 = a[2] * math.pi / 180
    lat2 = b[2] * math.pi / 180
    d_lat = (b[2] - a[2]) * math.pi / 180
    d_lon = (b[3] - a[3]) * math.pi / 180
    h = math.sin(d_lat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(d_lon / 2) ** 2
    return 2 * radius * math.asin(min(1, math.sqrt(h)))


def write_tsplib(path, cities, metres_per_unit=1):
    n = len(cities)
    lines = [
        "NAME: tspexplorer",
        "TYPE: TSP",
        f"DIMENSION: {n}",
        "EDGE_WEIGHT_TYPE: EXPLICIT",
        "EDGE_WEIGHT_FORMAT: FULL_MATRIX",
        "EDGE_WEIGHT_SECTION",
    ]
    for a in cities:
        lines.append(" ".join(str(round(haversine(a, b) * 1000 / metres_per_unit)) for b in cities))
    lines.append("EOF")
    path.write_text("\n".join(lines) + "\n")


def tour_from_edges(edges, n):
    adjacency = [[] for _ in range(n)]
    for a, b in edges:
        adjacency[a].append(b)
        adjacency[b].append(a)
    tour, previous, current = [0], -1, 0
    while len(tour) < n:
        nxt = next(c for c in adjacency[current] if c != previous)
        tour.append(nxt)
        previous, current = current, nxt
    return tour


def run_linkern(work, n):
    """Concorde's Lin–Kernighan tour, or None if it couldn't run."""
    out = work / "lk.edges"
    result = subprocess.run(
        [str(LINKERN), "-s", "1", "-o", str(out), "inst.tsp"],
        cwd=work, capture_output=True, text=True, timeout=300,
    )
    if result.returncode != 0 or not out.exists():
        print(f"    linkern failed, skipping its step:\n{result.stderr.strip()}")
        return None
    rows = [line.split() for line in out.read_text().split("\n")[1:] if line.strip()]
    return tour_from_edges([(int(r[0]), int(r[1])) for r in rows], n)


def concorde(work, options):
    """Runs Concorde and returns its log. Exits if it fails."""
    for name in ("out.sol", "lp.x"):
        (work / name).unlink(missing_ok=True)
    result = subprocess.run(
        # No -x (delete work files): it exits with an error when a file it expects
        # to delete was never written. The temporary directory is removed anyway.
        [str(CONCORDE), "-s", "1", *options, "-o", "out.sol", "-X", "lp.x", "inst.tsp"],
        cwd=work, capture_output=True, text=True, timeout=3600,
    )
    if result.returncode != 0 or not (work / "out.sol").exists():
        sys.exit(f"Concorde {' '.join(options)} failed:\n{result.stdout}\n{result.stderr}")
    return result.stdout


def run_stages(work):
    """LP bound and solution after each cutting-plane stage. A stage whose LP is
    identical to the one before it is dropped, since it adds nothing to show."""
    stages = []
    for name, options in LP_STAGES:
        log = concorde(work, options)
        match = re.search(r"(?:Final lower bound|Bound:) ([\d.]+)", log)
        if not match or not (work / "lp.x").exists():
            sys.exit(f"Concorde stage {name} wrote no LP solution:\n{log}")
        rows = [line.split() for line in (work / "lp.x").read_text().split("\n")[1:] if line.strip()]
        x = sorted([min(int(r[0]), int(r[1])), max(int(r[0]), int(r[1])), round(float(r[2]), 4)] for r in rows)
        bound = float(match.group(1))
        if stages and stages[-1]["x"] == x and abs(stages[-1]["bound"] - bound) < 0.5:
            continue
        stages.append({"name": name, "bound": bound, "x": x})
    return stages


def run_concorde(work, n):
    log = concorde(work, [])

    numbers = (work / "out.sol").read_text().split()
    tour = [int(x) for x in numbers[1:]]
    if sorted(tour) != list(range(n)):
        sys.exit(f"Concorde returned an invalid tour: {tour}")

    def find(pattern, cast=float):
        match = re.search(pattern, log)
        return cast(match.group(1)) if match else None

    info = {
        "tour": tour,
        "method": "branchAndCut" if n >= LP_MIN_CITIES else "heldKarp",
        "seconds": find(r"Total Running Time: ([\d.]+)"),
        "bbNodes": find(r"Number of bbnodes: (\d+)", int),
    }
    if n >= LP_MIN_CITIES:
        info["stages"] = run_stages(work)
    return info


def main():
    for tool in (CONCORDE, LINKERN):
        if not tool.exists():
            sys.exit(f"{tool} not found. Run Concorde/build_concorde.sh first.")

    instances = []
    for region, cities in load_regions().items():
        for count in range(3, len(cities) + 1):
            subset = cities[:count]
            print(f"{region}: {count} cities")
            with tempfile.TemporaryDirectory() as tmp:
                work = Path(tmp)
                unit = 1
                if count < LP_MIN_CITIES:
                    longest = max(haversine(a, b) * 1000 for a in subset for b in subset)
                    unit = max(1, math.ceil(longest / HELD_KARP_MAX_EDGE))
                write_tsplib(work / "inst.tsp", subset, unit)
                instance = {"cities": [f"{c[0]}|{c[1]}" for c in subset]}
                if count >= LP_MIN_CITIES:
                    lk = run_linkern(work, count)
                    if lk:
                        instance["lkTour"] = lk
                instance.update(run_concorde(work, count))
                # Drop empty fields so the JSON stays small.
                instances.append({k: v for k, v in instance.items() if v is not None})

    OUTPUT.write_text(json.dumps({
        "solver": "Concorde TSP Solver (github.com/matthelb/concorde) with QSopt",
        "generated": date.today().isoformat(),
        "instances": instances,
    }, ensure_ascii=False, separators=(",", ":")))
    print(f"\nWrote {len(instances)} solved instances to {OUTPUT}")


if __name__ == "__main__":
    main()
