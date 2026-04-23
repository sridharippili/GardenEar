import Foundation
import MapKit

// MARK: - Unified annotation type for SwiftUI Map

/// A pin is either a single sighting or a cluster of nearby sightings.
enum MapPin: Identifiable {
    case single(Sighting)
    case cluster(id: String, center: CLLocationCoordinate2D, count: Int)

    var id: String {
        switch self {
        case .single(let s):              return s.id
        case .cluster(let id, _, _):     return "cluster-\(id)"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .single(let s):
            return CLLocationCoordinate2D(
                latitude:  s.latitude  ?? 0,
                longitude: s.longitude ?? 0
            )
        case .cluster(_, let center, _):
            return center
        }
    }
}

// MARK: - ViewModel

@MainActor
class MapViewModel: ObservableObject {
    /// All sightings that have a GPS coordinate — used for the stats chip.
    @Published var sightingsWithLocation: [Sighting] = []

    /// The pins currently rendered on the map (filtered + clustered).
    @Published var displayPins: [MapPin] = []

    /// True while the initial DB fetch is in flight.
    @Published var isLoading: Bool = true

    private var lastRegion: MKCoordinateRegion?

    // MARK: - Load

    func load() {
        let all = (try? DatabaseManager.shared.getAllSightings()) ?? []
        sightingsWithLocation = all.filter { $0.latitude != nil && $0.longitude != nil }

        // Refresh pins with the stored region, or fall back to showing everything.
        if let region = lastRegion {
            refreshPins(for: region)
        } else {
            displayPins = sightingsWithLocation.map { .single($0) }
        }
        isLoading = false
    }

    // MARK: - Region update (called when the user zooms/pans)

    /// Recomputes `displayPins` for the new region.
    /// Only triggers a real recompute when the zoom level changes by > 5 %
    /// so panning doesn't cause constant annotation churn.
    func updateRegion(_ region: MKCoordinateRegion) {
        if let last = lastRegion {
            let spanRatio = abs(last.span.latitudeDelta - region.span.latitudeDelta)
                          / last.span.latitudeDelta
            guard spanRatio > 0.05 else {
                // Pan without zoom — keep the existing pins, just remember the new center.
                lastRegion = region
                return
            }
        }
        lastRegion = region
        refreshPins(for: region)
    }

    // MARK: - Pin computation

    private func refreshPins(for region: MKCoordinateRegion) {
        // ── Step 1: visible-region filter ────────────────────────────────
        // Use a 1.3× buffer so pins near the edge don't pop in/out.
        let buffer = 1.3
        let halfLat = region.span.latitudeDelta  / 2 * buffer
        let halfLon = region.span.longitudeDelta / 2 * buffer
        let minLat  = region.center.latitude  - halfLat
        let maxLat  = region.center.latitude  + halfLat
        let minLon  = region.center.longitude - halfLon
        let maxLon  = region.center.longitude + halfLon

        let visible = sightingsWithLocation.filter { s in
            guard let lat = s.latitude, let lon = s.longitude else { return false }
            return lat >= minLat && lat <= maxLat
                && lon >= minLon && lon <= maxLon
        }

        // ── Step 2: cluster when total > 20 and zoomed out ──────────────
        let shouldCluster = sightingsWithLocation.count > 20
                         && region.span.latitudeDelta > 0.5

        displayPins = shouldCluster
            ? cluster(visible, in: region)
            : visible.map { .single($0) }
    }

    /// Simple 5 × 5 grid clustering.
    private func cluster(_ sightings: [Sighting],
                         in region: MKCoordinateRegion) -> [MapPin] {
        let gridSize = 5
        let minLat   = region.center.latitude  - region.span.latitudeDelta  / 2
        let minLon   = region.center.longitude - region.span.longitudeDelta / 2

        // Bucket each sighting into a grid cell.
        var grid: [String: [Sighting]] = [:]
        for s in sightings {
            guard let lat = s.latitude, let lon = s.longitude else { continue }
            let row = max(0, min(Int((lat - minLat) / region.span.latitudeDelta  * Double(gridSize)), gridSize - 1))
            let col = max(0, min(Int((lon - minLon) / region.span.longitudeDelta * Double(gridSize)), gridSize - 1))
            grid["\(row)-\(col)", default: []].append(s)
        }

        // Convert each cell into either a single pin or a cluster pin.
        return grid.flatMap { key, group -> [MapPin] in
            if group.count == 1 { return [.single(group[0])] }

            let avgLat = group.compactMap { $0.latitude  }.reduce(0, +) / Double(group.count)
            let avgLon = group.compactMap { $0.longitude }.reduce(0, +) / Double(group.count)
            return [.cluster(
                id:     key,
                center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                count:  group.count
            )]
        }
    }
}
