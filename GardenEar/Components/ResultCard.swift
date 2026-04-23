import SwiftUI

struct ResultCard: View {
    @Binding var detectedSpecies: [DetectedSpecies]
    let onToggle: (UUID) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var surfaceColor: Color {
        colorScheme == .dark ? Theme.surfaceDark : Theme.surface
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("\(detectedSpecies.count) species detected")
                    .font(Theme.headingFont)
                    .foregroundColor(.primary)
                Text("Tap to deselect before saving")
                    .font(Theme.captionFont)
                    .foregroundColor(.secondary)
            }

            Divider()
                .background(Theme.accent.opacity(0.3))

            // Scrollable species list (capped at 320 pt)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(detectedSpecies) { detection in
                        SpeciesRow(detection: detection) {
                            onToggle(detection.id)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(16)
        .background(surfaceColor)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 4)
    }
}
