import SwiftUI

struct LifeStageBadge: View {
    let lifeStage: String

    private var colors: (background: Color, text: Color) {
        switch lifeStage.lowercased() {
        case "chick":    return (Theme.chickFill,    Theme.chickText)
        case "juvenile": return (Theme.juvenileFill, Theme.juvenileText)
        case "adult":    return (Theme.adultFill,    Theme.adultText)
        default:         return (Theme.unknownFill,  Theme.unknownText)
        }
    }

    var body: some View {
        Text(lifeStage.capitalized)
            .font(Theme.badgeFont)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(colors.background)
            .foregroundColor(colors.text)
            .clipShape(Capsule())
    }
}
