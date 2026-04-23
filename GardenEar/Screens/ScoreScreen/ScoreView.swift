import SwiftUI

struct ScoreView: View {
    @StateObject private var viewModel = ScoreViewModel()
    @Environment(\.colorScheme) private var colorScheme

    private var bgColor: Color {
        colorScheme == .dark ? Theme.backgroundDark : Theme.background
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    scoreHeader
                    heroCard
                    if let best = viewModel.personalBest {
                        personalBestBanner(best: best)
                    }
                    barChartSection
                    speciesListSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear { viewModel.load() }
        .task { viewModel.load() }
        .onReceive(
            NotificationCenter.default.publisher(for: .sightingSaved)
        ) { _ in viewModel.load() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in viewModel.load() }
    }

    // MARK: - 0. Score header

    private var scoreHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Score")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Theme.primary)
            Text("Your backyard biodiversity")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - 1. Hero card

    private var heroCard: some View {
        let uniqueCount = viewModel.currentMonthScore?.uniqueSpecies ?? 0
        let progress = min(CGFloat(uniqueCount) / 10.0, 1.0)
        let surfaceColor = colorScheme == .dark ? Theme.surfaceDark : Theme.surface

        return VStack(spacing: 12) {
            Text(viewModel.currentMonthDisplay)
                .font(Theme.captionFont)
                .foregroundColor(.secondary)

            Text("\(uniqueCount)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("species identified this month")
                .font(Theme.captionFont)
                .foregroundColor(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.accent.opacity(0.3))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.primary)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.primary.opacity(0.8), Theme.primary.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }

    // MARK: - 2. Personal best banner

    @ViewBuilder
    private func personalBestBanner(best: MonthlyScore) -> some View {
        let isCurrentBest = best.month == viewModel.currentMonthString

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Personal best")
                    .font(Theme.captionFont)
                    .foregroundColor(.secondary)
                Text("\(displayMonth(best.month)): \(best.uniqueSpecies) species")
                    .font(Theme.bodyFont.weight(.semibold))
                    .foregroundColor(.primary)
            }
            Spacer()
            if isCurrentBest {
                Text("Current best!")
                    .font(Theme.badgeFont)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.teal)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Theme.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.secondary.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 3. Bar chart

    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 6 months")
                .font(Theme.captionFont.weight(.semibold))
                .foregroundColor(.secondary)

            MonthlyBarChart(
                scores: viewModel.last6Months,
                currentMonth: viewModel.currentMonthString
            )
        }
        .padding(14)
        .background(colorScheme == .dark ? Theme.surfaceDark : Theme.surface)
        .cornerRadius(14)
    }

    // MARK: - 4. Species list this month

    @ViewBuilder
    private var speciesListSection: some View {
        if !viewModel.speciesThisMonth.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Seen this month")
                    .font(Theme.captionFont.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                ForEach(viewModel.speciesThisMonth, id: \.name) { species in
                    HStack {
                        Text(species.name)
                            .font(Theme.bodyFont)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("×\(species.count)")
                            .font(Theme.badgeFont)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 8)

                    if species.name != viewModel.speciesThisMonth.last?.name {
                        Divider()
                    }
                }
            }
            .padding(14)
            .background(colorScheme == .dark ? Theme.surfaceDark : Theme.surface)
            .cornerRadius(14)
        }
    }

    // MARK: - Helper

    private func displayMonth(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let monthInt = Int(parts[1]),
              (1...12).contains(monthInt)
        else { return month }
        var comps = DateComponents()
        comps.year = year; comps.month = monthInt; comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return month }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
