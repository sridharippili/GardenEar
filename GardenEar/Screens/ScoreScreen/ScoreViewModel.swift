import Foundation

@MainActor
class ScoreViewModel: ObservableObject {
    @Published var currentMonthScore: MonthlyScore?
    @Published var allScores: [MonthlyScore] = []
    @Published var speciesThisMonth: [(name: String, count: Int)] = []
    @Published var personalBest: MonthlyScore?

    // MARK: - Computed helpers

    var currentMonthString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    var currentMonthDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    /// Last 6 calendar months, oldest → newest, padded with zero scores where needed.
    var last6Months: [MonthlyScore] {
        let calendar = Calendar.current
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        let scoresByMonth = Dictionary(uniqueKeysWithValues: allScores.map { ($0.month, $0) })

        // Generate 5 months ago … current month (oldest first)
        return (0..<6).reversed().compactMap { offset -> MonthlyScore? in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let key = f.string(from: date)
            return scoresByMonth[key] ?? MonthlyScore(month: key, uniqueSpecies: 0, totalSightings: 0)
        }
    }

    // MARK: - Load

    func load() {
        do {
            allScores        = try DatabaseManager.shared.getAllMonthlyScores()
            currentMonthScore = allScores.first { $0.month == currentMonthString }
            speciesThisMonth  = try DatabaseManager.shared.getSpeciesForMonth(currentMonthString)
            personalBest      = allScores.max { $0.uniqueSpecies < $1.uniqueSpecies }
        } catch {
            print("ScoreViewModel.load error: \(error.localizedDescription)")
        }
    }
}
