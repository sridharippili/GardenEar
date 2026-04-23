import Foundation

// MARK: - Detected species (single candidate from the server)

struct DetectedSpecies: Identifiable {
    let id = UUID()
    let species: String
    let scientificName: String
    let confidence: Double
    var isSelected: Bool

    init(species: String,
         scientificName: String = "",
         confidence: Double,
         isSelected: Bool = true) {
        self.species = species
        self.scientificName = scientificName
        self.confidence = confidence
        self.isSelected = isSelected
    }
}

// MARK: - Shared result type

struct IdentificationResult {
    let species: String
    let lifeStage: String
    let callType: String
    let confidence: Double
    let rawResponse: String
    let providerName: String
    let allDetections: [DetectedSpecies]
}

// MARK: - Provider protocol

protocol AudioIdentificationProvider {
    var name: String { get }
    func identify(audioURL: URL) async throws -> IdentificationResult
}

// MARK: - Shared error type

enum AppError: LocalizedError {
    case message(String)
    case offlineNoModel

    var errorDescription: String? {
        switch self {
        case .message(let m):  return m
        case .offlineNoModel:  return "You're offline and no local model is downloaded."
        }
    }

    var isOfflineError: Bool {
        if case .offlineNoModel = self { return true }
        return false
    }
}

// MARK: - Main service

struct AudioIdentificationService {

    /// Priority:
    ///   1. Online  → NatureLMProvider (router → Kaggle/Colab)
    ///   2. Offline + local model  → BirdNETLocalProvider
    ///   3. Offline + no model     → throw offlineNoModel
    @MainActor
    static var provider: AudioIdentificationProvider {
        let isOnline = NetworkMonitor.shared.isConnected
        let hasLocalModel = OfflineModelManager.shared.isBirdNetDownloaded
        if isOnline {
            return NatureLMProvider()
        } else if hasLocalModel {
            return BirdNETLocalProvider()
        } else {
            return BirdNETProvider() // falls back gracefully
        }
    }

    static func identify(audioURL: URL) async throws -> IdentificationResult {
        let p = await MainActor.run { provider }
        return try await p.identify(audioURL: audioURL)
    }

    static func testConnection() async {
        let p = await MainActor.run { provider }
        print("[GardenEar] Using provider: \(p.name)")
    }
}
