import SwiftUI
import MapKit
import CoreLocation

// MARK: - Data container

struct FieldNotesCardData {
    let sighting: Sighting
    let scientificName: String
    let barHeights: [CGFloat]   // 40 bars, values 0…1
    let mapImage: UIImage?
    let locationName: String
}

// MARK: - Async builder

/// Loads the map snapshot + reverse-geocode result, then returns a fully-populated
/// `FieldNotesCardData` ready for `ImageRenderer`.
func buildFieldNotesCardData(
    for sighting: Sighting,
    scientificName: String
) async -> FieldNotesCardData {
    async let mapImage    = snapshotMap(latitude: sighting.latitude, longitude: sighting.longitude)
    async let locationName = reverseGeocode(latitude: sighting.latitude, longitude: sighting.longitude)

    return FieldNotesCardData(
        sighting:       sighting,
        scientificName: scientificName,
        barHeights:     makeBarHeights(seed: sighting.id),
        mapImage:       await mapImage,
        locationName:   await locationName
    )
}

// MARK: - Private helpers

/// 40 smooth bar heights (0…1) derived deterministically from a seed string.
private func makeBarHeights(seed: String) -> [CGFloat] {
    let seedVal = seed.unicodeScalars.reduce(UInt64(7)) { $0 &* 31 &+ UInt64($1.value) }
    var rng     = CardBarRNG(seed: seedVal)
    var heights = [CGFloat]()
    var prev: CGFloat = 0.5
    for _ in 0 ..< 40 {
        let t = CGFloat.random(in: 0.08 ... 1.0, using: &rng)
        let h = prev * 0.35 + t * 0.65   // smooth blend
        heights.append(h)
        prev = h
    }
    return heights
}

/// Renders a map tile at the sighting coordinate and draws a teal pin over it.
private func snapshotMap(latitude: Double?, longitude: Double?) async -> UIImage? {
    guard let lat = latitude, let lon = longitude else { return nil }

    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    let opts        = MKMapSnapshotter.Options()
    opts.region     = MKCoordinateRegion(
        center: coordinate,
        span:   MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    opts.size       = CGSize(width: 335, height: 160)
    opts.scale      = 3
    opts.mapType    = .standard

    return await withCheckedContinuation { continuation in
        MKMapSnapshotter(options: opts).start { snapshot, _ in
            guard let snapshot else { continuation.resume(returning: nil); return }

            let base  = snapshot.image
            let point = snapshot.point(for: coordinate)

            UIGraphicsBeginImageContextWithOptions(base.size, true, base.scale)
            defer { UIGraphicsEndImageContext() }
            base.draw(at: .zero)

            guard let ctx = UIGraphicsGetCurrentContext() else {
                continuation.resume(returning: UIGraphicsGetImageFromCurrentImageContext())
                return
            }

            // Teal filled circle pin
            let pinR: CGFloat = 8
            let pinRect = CGRect(x: point.x - pinR, y: point.y - pinR,
                                 width: pinR * 2,   height: pinR * 2)
            ctx.setFillColor(UIColor(red: 0.16, green: 0.77, blue: 0.66, alpha: 1).cgColor)
            ctx.fillEllipse(in: pinRect)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(2)
            ctx.strokeEllipse(in: pinRect)

            continuation.resume(returning: UIGraphicsGetImageFromCurrentImageContext())
        }
    }
}

/// Returns "Neighbourhood, City" via reverse geocoding, or "" when unavailable.
private func reverseGeocode(latitude: Double?, longitude: Double?) async -> String {
    guard let lat = latitude, let lon = longitude else { return "" }
    let location = CLLocation(latitude: lat, longitude: lon)
    guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
    else { return "" }

    var parts: [String] = []
    if let sub = placemark.subLocality  { parts.append(sub) }
    if let city = placemark.locality, !parts.contains(city) { parts.append(city) }
    if parts.isEmpty, let area = placemark.administrativeArea { parts.append(area) }
    return parts.prefix(2).joined(separator: ", ")
}

// MARK: - Deterministic RNG (private to this file)

private struct CardBarRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Field Notes card view (rendered via ImageRenderer)

struct FieldNotesCardView: View {

    let data: FieldNotesCardData

    // ── Palette ─────────────────────────────────────────────────────────
    private let bg      = Color(red: 0.08, green: 0.14, blue: 0.10)   // deep forest
    private let surface = Color(red: 0.12, green: 0.20, blue: 0.14)   // card panel
    private let cream   = Color(red: 0.93, green: 0.89, blue: 0.82)   // off-white text
    private let gold    = Color(red: 0.84, green: 0.70, blue: 0.38)   // accent dividers
    private let teal    = Color(red: 0.16, green: 0.77, blue: 0.66)   // waveform / pin

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(bg)

            VStack(spacing: 0) {
                header
                goldLine

                // ── Main content ─────────────────────────────────────
                VStack(spacing: 14) {
                    namesSection
                    tealDivider
                    waveformBars
                    mapSection
                    infoRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                Spacer(minLength: 0)

                goldLine
                footer
            }
        }
        .frame(width: 375, height: 600)
        .shadow(color: .black.opacity(0.40), radius: 28, x: 0, y: 10)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GardenEar")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(cream)
                Text("FIELD NOTES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(cream.opacity(0.45))
                    .tracking(2.5)
            }
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 20))
                .foregroundColor(teal)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Dividers

    private var goldLine: some View {
        Rectangle()
            .fill(gold.opacity(0.55))
            .frame(height: 0.75)
    }

    private var tealDivider: some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(teal.opacity(0.45))
                .frame(height: 0.75)
            Circle()
                .fill(teal.opacity(0.65))
                .frame(width: 4, height: 4)
            Rectangle()
                .fill(teal.opacity(0.45))
                .frame(height: 0.75)
        }
    }

    // MARK: - Species names

    private var namesSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(data.sighting.speciesName)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(cream)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if !data.scientificName.isEmpty {
                Text(data.scientificName)
                    .font(Font.system(size: 14, design: .serif).italic())
                    .foregroundColor(cream.opacity(0.50))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Waveform bars

    private var waveformBars: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0 ..< data.barHeights.count, id: \.self) { i in
                let h = data.barHeights[i]
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(teal.opacity(0.35 + h * 0.65))
                    .frame(width: 4.5, height: max(4, h * 36))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 40)
    }

    // MARK: - Map snapshot

    private var mapSection: some View {
        Group {
            if let img = data.mapImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(gold.opacity(0.30), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .foregroundColor(cream.opacity(0.35))
                            Text("Location not recorded")
                                .font(.system(size: 13))
                                .foregroundColor(cream.opacity(0.35))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(gold.opacity(0.18), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Info row  (date | confidence | source)

    private var infoRow: some View {
        HStack(spacing: 0) {
            infoCol(top: shortDate, bottom: shortTime)
            Spacer()
            Rectangle().fill(gold.opacity(0.28)).frame(width: 0.75, height: 30)
            Spacer()
            infoCol(top: confidenceLabel, bottom: "Confidence")
            Spacer()
            Rectangle().fill(gold.opacity(0.28)).frame(width: 0.75, height: 30)
            Spacer()
            infoCol(top: providerLabel, bottom: "Source")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(surface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(gold.opacity(0.20), lineWidth: 0.75)
        )
    }

    private func infoCol(top: String, bottom: String) -> some View {
        VStack(spacing: 3) {
            Text(top)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(cream)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(bottom)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(cream.opacity(0.45))
                .tracking(0.8)
                .textCase(.uppercase)
        }
        .frame(minWidth: 72)
    }

    // MARK: - Footer  (location + branding)

    private var footer: some View {
        VStack(spacing: 5) {
            if !data.locationName.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(teal.opacity(0.80))
                    Text(data.locationName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(cream.opacity(0.60))
                        .lineLimit(1)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(teal.opacity(0.55))
                Text("Identified with GardenEar")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(cream.opacity(0.38))
                    .tracking(0.4)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Computed labels

    private var shortDate: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: data.sighting.recordedAt)
    }

    private var shortTime: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: data.sighting.recordedAt)
    }

    private var confidenceLabel: String {
        "\(Int(data.sighting.confidence * 100))%"
    }

    private var providerLabel: String {
        let p = data.sighting.providerName
        if p.lowercased().contains("naturelm") { return "NatureLM" }
        if p.lowercased().contains("local")    { return "BirdNET" }
        if p.lowercased().contains("birdnet")  { return "BirdNET" }
        return p.isEmpty ? "BirdNET" : String(p.prefix(9))
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
