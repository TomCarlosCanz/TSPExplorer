import Foundation

/// Pairwise great-circle distances (in kilometres) between a list of cities.
/// Algorithms only work with city *indices* into this matrix.
struct DistanceMatrix {
    let count: Int
    private var values: [Double]

    init(cities: [City]) {
        count = cities.count
        values = Array(repeating: 0, count: count * count)
        for i in 0..<count {
            for j in (i + 1)..<count {
                let d = DistanceMatrix.haversine(cities[i], cities[j])
                values[i * count + j] = d
                values[j * count + i] = d
            }
        }
    }

    subscript(_ i: Int, _ j: Int) -> Double {
        values[i * count + j]
    }

    /// Length of a route. `closed` adds the edge from the last city back to the first.
    func length(of route: [Int], closed: Bool = true) -> Double {
        guard route.count > 1 else { return 0 }
        var total = 0.0
        for k in 0..<(route.count - 1) {
            total += self[route[k], route[k + 1]]
        }
        if closed {
            total += self[route[route.count - 1], route[0]]
        }
        return total
    }

    /// Great-circle distance on a sphere with Earth's mean radius.
    static func haversine(_ a: City, _ b: City) -> Double {
        let radius = 6371.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }
}

extension Double {
    /// "1,234 km" (or "1.234 km" in German)
    var km: String {
        formatted(.number.precision(.fractionLength(0)).locale(Localization.shared.language.locale)) + " km"
    }
}
