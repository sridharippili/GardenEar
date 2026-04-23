import SwiftUI

struct SightingRow: View {
    let sighting: Sighting

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: sighting.recordedAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Species + call type
            VStack(alignment: .leading, spacing: 3) {
                Text(sighting.speciesName)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                Text(sighting.callType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Life stage badge
            LifeStageBadge(lifeStage: sighting.lifeStage)

            // Time
            Text(timeString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())  // full-width tap area
        .padding(.vertical, 4)
    }
}
