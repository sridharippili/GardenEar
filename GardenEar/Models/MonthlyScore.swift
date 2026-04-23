import Foundation

struct MonthlyScore: Identifiable {
    var id: String { month }
    var month: String         // "YYYY-MM"
    var uniqueSpecies: Int
    var totalSightings: Int
}
