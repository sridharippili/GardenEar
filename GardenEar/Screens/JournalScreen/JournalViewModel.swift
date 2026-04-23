import Foundation

@MainActor
class JournalViewModel: ObservableObject {
    @Published var sightings: [Sighting] = []
    @Published var totalUnique: Int = 0

    // MARK: - Grouped data

    /// Sightings grouped by calendar day, most recent day first.
    var groupedByDate: [(date: String, sightings: [Sighting])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"   // e.g. "Monday, April 11"

        var groups: [String: [Sighting]] = [:]
        for sighting in sightings {
            let key = formatter.string(from: sighting.recordedAt)
            groups[key, default: []].append(sighting)
        }

        // Sort groups by the most recent sighting in each group (descending)
        return groups
            .map { (date: $0.key, sightings: $0.value) }
            .sorted { lhs, rhs in
                let lDate = lhs.sightings.first?.recordedAt ?? .distantPast
                let rDate = rhs.sightings.first?.recordedAt ?? .distantPast
                return lDate > rDate
            }
    }

    // MARK: - Public interface

    func load() {
        do {
            sightings = try DatabaseManager.shared.getAllSightings()
            computeUnique()
        } catch {
            print("JournalViewModel.load error: \(error.localizedDescription)")
        }
    }

    func delete(sighting: Sighting) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: sighting.recordedAt)
        do {
            try DatabaseManager.shared.deleteSighting(id: sighting.id)
            try DatabaseManager.shared.upsertMonthlyScore(forMonth: month)
        } catch {
            print("JournalViewModel.delete error: \(error.localizedDescription)")
        }
        load()
    }

    // MARK: - Private

    private func computeUnique() {
        // Lowercase dedup so "American Robin" and "american robin" count as one
        totalUnique = Set(sightings.map { $0.speciesName.lowercased() }).count
    }
}
