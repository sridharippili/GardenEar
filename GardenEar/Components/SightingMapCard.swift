import SwiftUI

struct SightingMapCard: View {
    let sighting: Sighting
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sighting.speciesName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(sighting.recordedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            HStack(spacing: 8) {
                LifeStageBadge(lifeStage: sighting.lifeStage)
                if sighting.callType != "Unknown" {
                    Text(sighting.callType)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
    }
}
