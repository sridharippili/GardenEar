import SwiftUI

struct MonthlyBarChart: View {
    let scores: [MonthlyScore]
    let currentMonth: String

    private let maxBarHeight: CGFloat = 120

    var body: some View {
        let peak = max(scores.map(\.uniqueSpecies).max() ?? 1, 1)

        HStack(alignment: .bottom, spacing: 6) {
            ForEach(scores) { score in
                barColumn(score: score, peak: peak)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func barColumn(score: MonthlyScore, peak: Int) -> some View {
        let isCurrentMonth = score.month == currentMonth
        let barHeight = score.uniqueSpecies > 0
            ? CGFloat(score.uniqueSpecies) / CGFloat(peak) * maxBarHeight
            : 4

        let barColor: Color = isCurrentMonth
            ? Theme.primary
            : Theme.accent.opacity(0.5)

        VStack(spacing: 4) {
            Text("\(score.uniqueSpecies)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(minWidth: 20)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(barColor)
                .frame(height: barHeight)
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.5), value: score.uniqueSpecies)

            Text(shortLabel(score.month))
                .font(.caption2.weight(isCurrentMonth ? .semibold : .regular))
                .foregroundColor(isCurrentMonth ? Theme.primary : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: maxBarHeight + 40, alignment: .bottom)
    }

    private func shortLabel(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2,
              let monthInt = Int(parts[1]),
              (1...12).contains(monthInt)
        else { return month }
        return DateFormatter().shortMonthSymbols[monthInt - 1]
    }
}
