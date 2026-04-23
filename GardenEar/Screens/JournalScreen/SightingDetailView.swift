import SwiftUI
import MapKit
import AVFoundation

struct SightingDetailView: View {
    let sighting: Sighting
    @StateObject private var viewModel = SightingDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Share-card state
    @State private var isPreparingCard = false
    @State private var cardImage: UIImage?
    @State private var showShareSheet  = false

    // Static waveform bar heights — deterministic from sighting id
    private let barHeights: [CGFloat] = {
        var rng = SeedableRNG(seed: 42)
        return (0..<20).map { _ in CGFloat.random(in: 8...40, using: &rng) }
    }()

    private var bgColor: Color {
        colorScheme == .dark ? Theme.backgroundDark : Theme.background
    }
    private var surfaceColor: Color {
        colorScheme == .dark ? Theme.surfaceDark : Theme.surface
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                audioCard
                if sighting.latitude != nil { locationCard }
                detectionsCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(sighting.speciesName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Journal")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(Theme.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    guard !isPreparingCard else { return }
                    isPreparingCard = true
                    Task { await prepareShareCard() }
                } label: {
                    if isPreparingCard {
                        ProgressView()
                            .tint(Theme.primary)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Theme.primary)
                    }
                }
            }
        }
        .onAppear { viewModel.setupAudio(path: sighting.audioPath) }
        .onDisappear { viewModel.cleanup() }
        .sheet(isPresented: $showShareSheet) {
            if let img = cardImage {
                ActivityView(items: [img])
            }
        }
    }

    // MARK: - Share card

    @MainActor
    private func prepareShareCard() async {
        let sciName = scientificName ?? ""
        let data    = await buildFieldNotesCardData(for: sighting, scientificName: sciName)
        let card    = FieldNotesCardView(data: data)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0          // retina-quality export
        renderer.proposedSize = .init(width: 375, height: 600)

        cardImage      = renderer.uiImage
        isPreparingCard = false
        if cardImage != nil { showShareSheet = true }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Species name
            Text(sighting.speciesName)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Theme.primary)

            // Scientific name (parsed from rawResponse if available)
            if let sci = scientificName, !sci.isEmpty {
                Text(sci)
                    .font(.system(size: 15).italic())
                    .foregroundColor(.secondary)
            }

            // Date + time
            Text(formattedDate)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            // Life stage + call type
            HStack(spacing: 8) {
                LifeStageBadge(lifeStage: sighting.lifeStage)
                if sighting.callType != "Unknown" && !sighting.callType.isEmpty {
                    Text(sighting.callType)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Confidence bar
            confidenceBar
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surfaceColor)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 3)
    }

    private var confidenceBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Confidence")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(sighting.confidence * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(confidenceColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(confidenceColor)
                        .frame(width: geo.size.width * CGFloat(sighting.confidence), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var confidenceColor: Color {
        sighting.confidence >= 0.7 ? Theme.primary :
        sighting.confidence >= 0.5 ? Color.orange : Color.red
    }

    // MARK: - Audio card

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Recording", systemImage: "waveform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            if viewModel.audioAvailable {
                audioPlayer
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.slash")
                        .foregroundColor(.secondary)
                    Text("Recording not available")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surfaceColor)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 3)
    }

    private var audioPlayer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                // Play/pause button
                Button { viewModel.togglePlayback() } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 44, height: 44)
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .offset(x: viewModel.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)

                // Static waveform
                GeometryReader { geo in
                    let playheadX = viewModel.duration > 0
                        ? geo.size.width * CGFloat(viewModel.currentTime / viewModel.duration)
                        : 0
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(0..<barHeights.count, id: \.self) { i in
                            let barX = geo.size.width * CGFloat(i) / CGFloat(barHeights.count)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barX < playheadX ? Theme.primary : Theme.accent.opacity(0.4))
                                .frame(width: (geo.size.width - CGFloat(barHeights.count - 1) * 2) / CGFloat(barHeights.count),
                                       height: barHeights[i])
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 40)
            }

            // Time labels
            HStack {
                Text(timeString(viewModel.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(timeString(viewModel.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Location card

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Recorded at", systemImage: "mappin.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            if let lat = sighting.latitude, let lon = sighting.longitude {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                // Static non-interactive map
                Map(coordinateRegion: .constant(region),
                    annotationItems: [sighting]) { s in
                    MapAnnotation(coordinate: coord) {
                        SightingMapPin(sighting: s)
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)
                .disabled(true)
                .allowsHitTesting(false)

                Text("\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                    .font(Theme.captionFont)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .foregroundColor(.secondary)
                    Text("Location not recorded")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surfaceColor)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 3)
    }

    // MARK: - All detections card

    private var detectionsCard: some View {
        let detections = viewModel.parseDetections(
            rawResponse:       sighting.rawResponse,
            primarySpecies:    sighting.speciesName,
            primaryConfidence: sighting.confidence
        )
        return VStack(alignment: .leading, spacing: 14) {
            Label("All species detected", systemImage: "list.bullet.rectangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 6) {
                ForEach(detections) { detection in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(detection.species)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            if !detection.scientificName.isEmpty {
                                Text(detection.scientificName)
                                    .font(.system(size: 12).italic())
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        let pillColor: Color = detection.confidence >= 0.7 ? Theme.primary :
                                               detection.confidence >= 0.5 ? Color.orange :
                                               Color(UIColor.systemGray4)
                        let pillTextColor: Color = detection.confidence < 0.5
                                               ? Color(UIColor.label) : .white
                        Text("\(Int(detection.confidence * 100))%")
                            .font(Theme.badgeFont)
                            .foregroundColor(pillTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(pillColor)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)

                    if detection.id != detections.last?.id {
                        Divider().background(Theme.accent.opacity(0.2))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surfaceColor)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 3)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d 'at' h:mm a"
        return f.string(from: sighting.recordedAt)
    }

    private var scientificName: String? {
        guard let data = sighting.rawResponse.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["scientific_name"] as? String
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Deterministic random for waveform bars

private struct SeedableRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
