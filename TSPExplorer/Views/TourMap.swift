import SwiftUI
import MapKit

/// Shared colours so the map and the legend always match.
enum Palette {
    static let tour = Color.accentColor
    static let candidate = Color.orange
    static let removed = Color.red
    static let ghost = Color.gray
    static let trail = Color.accentColor
}

/// A polyline ready for the map.
private struct Segment: Identifiable {
    let id: Int
    let points: [CLLocationCoordinate2D]
    var weight: Double = 1
}

/// The MapKit map that draws the current animation step on real geography.
struct TourMap: View {
    @Bindable var model: ExplorerModel

    var body: some View {
        let active = model.activeCities
        let step = model.displayStep
        let indexByID = Dictionary(active.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })

        let trails = weightedSegments(step?.weighted ?? [], in: active)
        let ghost = routeSegments(step?.ghost ?? [], closed: true, in: active)
        let edges = edgeSegments(step?.edges ?? [], in: active)
        let route = routeSegments(step?.path ?? [], closed: step?.isClosed ?? false, in: active)
        let removed = edgeSegments(step?.removed ?? [], in: active)
        let candidates = edgeSegments(step?.candidates ?? [], in: active)

        Map(position: $model.cameraPosition) {
            ForEach(trails) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.trail.opacity(0.15 + 0.65 * segment.weight), lineWidth: 1 + 6 * segment.weight)
            }

            ForEach(ghost) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.ghost.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 6]))
            }

            ForEach(edges) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.tour, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }

            ForEach(route) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.tour, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            ForEach(removed) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.removed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [5, 6]))
            }

            ForEach(candidates) { segment in
                MapPolyline(coordinates: segment.points)
                    .stroke(Palette.candidate, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }

            ForEach(model.visibleCities) { city in
                Annotation(city.displayName, coordinate: city.coordinate, anchor: .center) {
                    CityDot(role: role(for: city, indexByID: indexByID, step: step))
                        .onTapGesture { model.toggle(city) }
                }
                .annotationTitles(model.showNames ? .automatic : .hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: Geometry helpers

    private func coordinates(_ indices: [Int], closed: Bool, in cities: [City]) -> [CLLocationCoordinate2D] {
        var points = indices.compactMap { cities.indices.contains($0) ? cities[$0].coordinate : nil }
        if closed, points.count > 1 { points.append(points[0]) }
        return points
    }

    private func routeSegments(_ route: [Int], closed: Bool, in cities: [City]) -> [Segment] {
        let points = coordinates(route, closed: closed, in: cities)
        return points.count > 1 ? [Segment(id: 0, points: points)] : []
    }

    private func edgeSegments(_ edges: [Edge], in cities: [City]) -> [Segment] {
        edges.enumerated().compactMap { index, edge in
            let points = coordinates([edge.a, edge.b], closed: false, in: cities)
            return points.count == 2 ? Segment(id: index, points: points) : nil
        }
    }

    private func weightedSegments(_ edges: [WeightedEdge], in cities: [City]) -> [Segment] {
        edges.enumerated().compactMap { index, weighted in
            let points = coordinates([weighted.edge.a, weighted.edge.b], closed: false, in: cities)
            return points.count == 2 ? Segment(id: index, points: points, weight: weighted.weight) : nil
        }
    }

    private func role(for city: City, indexByID: [String: Int], step: SolverStep?) -> CityDot.Role {
        guard let index = indexByID[city.id] else { return .inactive }
        guard let step else { return .normal }
        if step.focus.contains(index) { return .focus }
        if step.path.first == index { return .start }
        return .normal
    }
}

/// A city marker. Tap to include or exclude the city.
struct CityDot: View {
    enum Role { case inactive, normal, start, focus }

    let role: Role

    private var size: CGFloat {
        switch role {
        case .inactive: return 10
        case .normal: return 14
        case .start: return 16
        case .focus: return 20
        }
    }

    private var fill: Color {
        switch role {
        case .inactive: return Color(.systemGray4)
        case .normal: return .white
        case .start: return Palette.tour
        case .focus: return Palette.candidate
        }
    }

    private var ring: Color {
        switch role {
        case .inactive: return Color(.systemGray)
        case .normal: return Palette.tour
        case .start, .focus: return .white
        }
    }

    var body: some View {
        Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(ring, lineWidth: role == .inactive ? 1.5 : 3))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .padding(8)
            .contentShape(Circle())
            .animation(.snappy(duration: 0.25), value: role)
    }
}
