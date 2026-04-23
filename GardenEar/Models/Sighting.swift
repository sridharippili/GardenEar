import Foundation

struct Sighting: Identifiable, Codable {
    var id: String
    var speciesName: String
    var lifeStage: String
    var callType: String
    var rawResponse: String
    var audioPath: String
    var latitude: Double?
    var longitude: Double?
    var recordedAt: Date
    var confidence: Double = 0.0
    var providerName: String = ""
}
