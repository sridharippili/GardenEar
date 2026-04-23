import SwiftUI

struct SpeciesRow: View {
    let detection: DetectedSpecies
    let onTap: () -> Void

    private var confidenceColor: Color {
        detection.confidence >= 0.7 ? Theme.primary :
        detection.confidence >= 0.5 ? Color.orange :
        Color(UIColor.systemGray4)
    }

    private var confidenceTextColor: Color {
        detection.confidence < 0.5 ? Color(UIColor.label) : .white
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {

                // Checkmark
                Image(systemName: detection.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(detection.isSelected
                                     ? Theme.primary
                                     : Color(UIColor.tertiaryLabel))

                // Species info
                VStack(alignment: .leading, spacing: 2) {
                    Text(detection.species)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    if !detection.scientificName.isEmpty {
                        Text(detection.scientificName)
                            .font(.system(size: 12))
                            .italic()
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Confidence pill
                Text("\(Int(detection.confidence * 100))%")
                    .font(Theme.badgeFont)
                    .foregroundColor(confidenceTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(confidenceColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                detection.isSelected
                    ? Theme.primary.opacity(0.08)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        detection.isSelected
                            ? Theme.primary.opacity(0.15)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: detection.isSelected)
    }
}
