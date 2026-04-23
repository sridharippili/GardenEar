import SwiftUI

struct SightingMapPin: View {
    let sighting: Sighting

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 36, height: 36)
                    .shadow(color: Theme.primary.opacity(0.4), radius: 4, y: 2)
                Text(String(sighting.speciesName.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            Triangle()
                .fill(Theme.primary)
                .frame(width: 10, height: 6)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
