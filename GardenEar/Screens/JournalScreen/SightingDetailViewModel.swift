import Foundation
import AVFoundation

@MainActor
class SightingDetailViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var audioAvailable = false

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    func setupAudio(path: String) {
        guard !path.isEmpty,
              FileManager.default.fileExists(atPath: path),
              let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) else {
            audioAvailable = false
            return
        }
        audioPlayer = player
        player.prepareToPlay()
        duration = player.duration
        audioAvailable = true
    }

    func togglePlayback() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            timer?.invalidate()
            isPlaying = false
        } else {
            // Reactivate audio session for playback
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let player = self.audioPlayer else { return }
                    self.currentTime = player.currentTime
                    if !player.isPlaying {
                        self.isPlaying = false
                        self.currentTime = 0
                        self.timer?.invalidate()
                    }
                }
            }
        }
    }

    func cleanup() {
        audioPlayer?.stop()
        timer?.invalidate()
        isPlaying = false
    }

    // MARK: - All detections parsed from raw JSON

    struct ParsedDetection: Identifiable {
        let id = UUID()
        let species: String
        let scientificName: String
        let confidence: Double
    }

    func parseDetections(rawResponse: String, primarySpecies: String, primaryConfidence: Double) -> [ParsedDetection] {
        guard let data = rawResponse.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let allArray = json["all_detections"] as? [[String: Any]],
              !allArray.isEmpty else {
            // Fall back to single entry
            return [ParsedDetection(species: primarySpecies,
                                    scientificName: "",
                                    confidence: primaryConfidence)]
        }
        return allArray.compactMap { item in
            guard let species = item["species"] as? String,
                  let conf   = item["confidence"] as? Double else { return nil }
            let sci = item["scientific_name"] as? String ?? ""
            return ParsedDetection(species: species, scientificName: sci, confidence: conf)
        }
    }
}
