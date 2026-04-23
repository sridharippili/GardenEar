import Foundation
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: Connection!

    // MARK: - Sightings columns
    private let sightings        = Table("sightings")
    private let sId              = Expression<String>("id")
    private let sSpeciesName     = Expression<String>("species_name")
    private let sLifeStage       = Expression<String>("life_stage")
    private let sCallType        = Expression<String>("call_type")
    private let sRawResponse     = Expression<String>("raw_response")
    private let sAudioPath       = Expression<String>("audio_path")
    private let sLatitude        = Expression<Double?>("latitude")
    private let sLongitude       = Expression<Double?>("longitude")
    private let sRecordedAt      = Expression<String>("recorded_at")
    private let sConfidence      = Expression<Double>("confidence")
    private let sProviderName    = Expression<String>("provider_name")

    // MARK: - Monthly scores columns
    private let monthlyScores    = Table("monthly_scores")
    private let msMonth          = Expression<String>("month")
    private let msUniqueSpecies  = Expression<Int>("unique_species")
    private let msTotalSightings = Expression<Int>("total_sightings")

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {
        do {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = docDir.appendingPathComponent("gardenear.db").path
            db = try Connection(dbPath)
            try createTables()
        } catch {
            print("DatabaseManager init error: \(error)")
        }
    }

    // MARK: - Public setup

    func setup() throws {
        // Migrate existing installs — ignore "duplicate column" errors safely
        let migrations = [
            "ALTER TABLE sightings ADD COLUMN confidence REAL DEFAULT 0",
            "ALTER TABLE sightings ADD COLUMN provider_name TEXT DEFAULT ''"
        ]
        for sql in migrations {
            do { try db.run(sql) } catch { /* column already exists — safe to ignore */ }
        }
    }

    // MARK: - Schema

    private func createTables() throws {
        try db.run(sightings.create(ifNotExists: true) { t in
            t.column(sId, primaryKey: true)
            t.column(sSpeciesName)
            t.column(sLifeStage)
            t.column(sCallType)
            t.column(sRawResponse)
            t.column(sAudioPath)
            t.column(sLatitude)
            t.column(sLongitude)
            t.column(sRecordedAt)
            t.column(sConfidence, defaultValue: 0.0)
            t.column(sProviderName, defaultValue: "")
        })

        try db.run(monthlyScores.create(ifNotExists: true) { t in
            t.column(msMonth, primaryKey: true)
            t.column(msUniqueSpecies)
            t.column(msTotalSightings)
        })
    }

    // MARK: - Sightings

    func insertSighting(_ sighting: Sighting) throws {
        let insert = sightings.insert(
            sId           <- sighting.id,
            sSpeciesName  <- sighting.speciesName,
            sLifeStage    <- sighting.lifeStage,
            sCallType     <- sighting.callType,
            sRawResponse  <- sighting.rawResponse,
            sAudioPath    <- sighting.audioPath,
            sLatitude     <- sighting.latitude,
            sLongitude    <- sighting.longitude,
            sRecordedAt   <- iso8601.string(from: sighting.recordedAt),
            sConfidence   <- sighting.confidence,
            sProviderName <- sighting.providerName
        )
        try db.run(insert)
    }

    func getAllSightings() throws -> [Sighting] {
        try db.prepare(sightings.order(sRecordedAt.desc)).map { row in
            Sighting(
                id:           row[sId],
                speciesName:  row[sSpeciesName],
                lifeStage:    row[sLifeStage],
                callType:     row[sCallType],
                rawResponse:  row[sRawResponse],
                audioPath:    row[sAudioPath],
                latitude:     row[sLatitude],
                longitude:    row[sLongitude],
                recordedAt:   iso8601.date(from: row[sRecordedAt]) ?? Date(),
                confidence:   row[sConfidence],
                providerName: row[sProviderName]
            )
        }
    }

    func deleteSighting(id: String) throws {
        try db.run(sightings.filter(sId == id).delete())
    }

    // MARK: - Monthly scores

    func upsertMonthlyScore(forMonth month: String) throws {
        let monthFilter = sRecordedAt.like("\(month)%")

        let total = try db.scalar(sightings.filter(monthFilter).count)

        let uniqueSpecies = try Set(
            db.prepare(sightings.filter(monthFilter).select(sSpeciesName))
              .map { $0[sSpeciesName] }
        ).count

        try db.run(monthlyScores.insert(
            or: .replace,
            msMonth          <- month,
            msUniqueSpecies  <- uniqueSpecies,
            msTotalSightings <- total
        ))
    }

    func getAllMonthlyScores() throws -> [MonthlyScore] {
        try db.prepare(monthlyScores.order(msMonth.desc)).map { row in
            MonthlyScore(
                month:          row[msMonth],
                uniqueSpecies:  row[msUniqueSpecies],
                totalSightings: row[msTotalSightings]
            )
        }
    }

    func getSpeciesForMonth(_ month: String) throws -> [(name: String, count: Int)] {
        let monthFilter = sRecordedAt.like("\(month)%")
        var counts: [String: Int] = [:]
        for row in try db.prepare(sightings.filter(monthFilter).select(sSpeciesName)) {
            counts[row[sSpeciesName], default: 0] += 1
        }
        return counts.map { (name: $0.key, count: $0.value) }
                     .sorted { $0.count > $1.count }
    }
}
