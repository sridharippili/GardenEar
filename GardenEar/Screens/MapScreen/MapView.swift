import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )
    @State private var selectedSighting: Sighting? = nil

    // Span clamps so zoom controls never go out of bounds
    private let minSpan = 0.001
    private let maxSpan = 150.0

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Map ──────────────────────────────────────────────────────
            Map(
                coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: viewModel.displayPins
            ) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    switch pin {
                    case .single(let sighting):
                        // Existing pin + tap → show card
                        SightingMapPin(sighting: sighting)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedSighting = sighting
                                }
                            }

                    case .cluster(_, _, let count):
                        // Cluster bubble → tap to zoom in
                        MapClusterPin(count: count)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    region.span = MKCoordinateSpan(
                                        latitudeDelta:  max(region.span.latitudeDelta  / 4, minSpan),
                                        longitudeDelta: max(region.span.longitudeDelta / 4, minSpan)
                                    )
                                    region.center = pin.coordinate
                                }
                            }
                    }
                }
            }
            .ignoresSafeArea()

            // ── Initial loading overlay ───────────────────────────────────
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
            }

            // ── Selected sighting card (slides up from bottom) ────────────
            if let sighting = selectedSighting {
                SightingMapCard(sighting: sighting) {
                    withAnimation { selectedSighting = nil }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }

            // ── Overlaid controls (stats chip + zoom buttons) ─────────────
            VStack(spacing: 0) {

                // Stats chip — top centre
                HStack {
                    Spacer()
                    Text(
                        "\(viewModel.sightingsWithLocation.count) " +
                        "pinned sighting\(viewModel.sightingsWithLocation.count == 1 ? "" : "s")"
                    )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemBackground))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                    Spacer()
                }
                .padding(.top, 60)

                Spacer()

                // Zoom controls — bottom right
                HStack {
                    Spacer()
                    zoomControls
                        .padding(.trailing, 16)
                        .padding(.bottom, 100) // clear tab bar (~83 pt) + breathing room
                }
            }
        }
        .onAppear {
            viewModel.load()
            centerOnSightings()
        }
        .onChange(of: viewModel.sightingsWithLocation.count) { _ in
            centerOnSightings()
        }
        // Recompute visible/clustered pins when the zoom level changes
        .onChange(of: region.span.latitudeDelta) { _ in
            viewModel.updateRegion(region)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.spring(),                  value: selectedSighting?.id)
    }

    // MARK: - Zoom helpers

    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span = MKCoordinateSpan(
                latitudeDelta:  max(region.span.latitudeDelta  / 2, minSpan),
                longitudeDelta: max(region.span.longitudeDelta / 2, minSpan)
            )
        }
    }

    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span = MKCoordinateSpan(
                latitudeDelta:  min(region.span.latitudeDelta  * 2, maxSpan),
                longitudeDelta: min(region.span.longitudeDelta * 2, maxSpan)
            )
        }
    }

    // MARK: - Zoom controls widget

    private var zoomControls: some View {
        VStack(spacing: 0) {
            // + button
            Button(action: zoomIn) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }

            Divider()
                .frame(width: 44)

            // − button
            Button(action: zoomOut) {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }

    // MARK: - Centre on all sightings

    private func centerOnSightings() {
        guard !viewModel.sightingsWithLocation.isEmpty else { return }
        let lats = viewModel.sightingsWithLocation.compactMap { $0.latitude }
        let lons = viewModel.sightingsWithLocation.compactMap { $0.longitude }
        guard let maxLat = lats.max(), let minLat = lats.min(),
              let maxLon = lons.max(), let minLon = lons.min() else { return }
        let centerLat = (maxLat + minLat) / 2
        let centerLon = (maxLon + minLon) / 2
        let spanLat = max((maxLat - minLat) * 1.5, 0.1)
        let spanLon = max((maxLon - minLon) * 1.5, 0.1)
        withAnimation {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span:   MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            )
        }
    }
}

// MARK: - Cluster pin view

private struct MapClusterPin: View {
    let count: Int

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .strokeBorder(Theme.primary.opacity(0.25), lineWidth: 4)
                .frame(width: 52, height: 52)

            // Filled circle
            Circle()
                .fill(Theme.primary)
                .frame(width: 42, height: 42)
                .shadow(color: Theme.primary.opacity(0.4), radius: 6, y: 2)

            // Count label
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
