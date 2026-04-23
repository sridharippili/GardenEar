import Foundation
import AVFoundation

@MainActor
class RecordViewModel: ObservableObject {

    enum State {
        case idle, recording, loading, result(Sighting), error(String)
    }

    @Published var state: State = .idle
    @Published var elapsedSeconds: Int = 0
    @Published var audioRecorder: AVAudioRecorder?

    @Published var detectedSpecies: [DetectedSpecies] = []
    @Published var saveMessage: String = ""
    @Published var showSaveConfirmation: Bool = false

    private var timer: Timer?
    private var audioFileURL: URL?

    // MARK: - Public interface

    func startRecording() {
        let handle: @Sendable (Bool) -> Void = { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard granted else {
                    self.state = .error("Microphone access denied. Enable it in Settings.")
                    return
                }
                self.beginRecording()
            }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: handle)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(handle)
        }
    }

    func stopRecording() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        Task { await identify() }
    }

    func analyzeUploadedFile(url: URL) {
        state = .loading
        Task {
            do {
                // Gain access to the security-scoped resource from Files
                guard url.startAccessingSecurityScopedResource() else {
                    state = .error("Could not access the selected file.")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                // Copy to temp dir for persistent read access
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: tmpURL.path) {
                    try FileManager.default.removeItem(at: tmpURL)
                }
                try FileManager.default.copyItem(at: url, to: tmpURL)
                audioFileURL = tmpURL

                let result = try await AudioIdentificationService.identify(audioURL: tmpURL)

                // Populate selectable species list
                if result.allDetections.isEmpty {
                    detectedSpecies = [DetectedSpecies(
                        species:        result.species,
                        scientificName: "",
                        confidence:     result.confidence,
                        isSelected:     true
                    )]
                } else {
                    detectedSpecies = result.allDetections
                }

                let sighting = Sighting(
                    id:           UUID().uuidString,
                    speciesName:  result.species,
                    lifeStage:    result.lifeStage,
                    callType:     result.callType,
                    rawResponse:  result.rawResponse,
                    audioPath:    tmpURL.path,
                    latitude:     LocationService.shared.lastLocation?.coordinate.latitude,
                    longitude:    LocationService.shared.lastLocation?.coordinate.longitude,
                    recordedAt:   Date(),
                    confidence:   result.confidence,
                    providerName: result.providerName
                )
                state = .result(sighting)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func retryWithLocalModel() {
        guard let url = audioFileURL else { return }
        state = .loading
        Task {
            do {
                let result = try await BirdNETLocalProvider().identify(audioURL: url)
                detectedSpecies = result.allDetections.isEmpty
                    ? [DetectedSpecies(species: result.species, confidence: result.confidence)]
                    : result.allDetections
                let sighting = Sighting(
                    id:           UUID().uuidString,
                    speciesName:  result.species,
                    lifeStage:    result.lifeStage,
                    callType:     result.callType,
                    rawResponse:  result.rawResponse,
                    audioPath:    url.path,
                    latitude:     LocationService.shared.lastLocation?.coordinate.latitude,
                    longitude:    LocationService.shared.lastLocation?.coordinate.longitude,
                    recordedAt:   Date(),
                    confidence:   result.confidence,
                    providerName: result.providerName
                )
                state = .result(sighting)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func toggleSpecies(id: UUID) {
        if let index = detectedSpecies.firstIndex(where: { $0.id == id }) {
            detectedSpecies[index].isSelected.toggle()
        }
    }

    func saveSelectedSightings() {
        guard case .result(let baseSighting) = state else { return }
        let selectedDetections = detectedSpecies.filter { $0.isSelected }
        guard !selectedDetections.isEmpty else { return }

        // Capture audio URL before any async gap
        let capturedAudioURL = audioFileURL

        Task { @MainActor in
            // Request location — never blocks saving if unavailable
            let location = await LocationService.shared.requestOneTimeLocation()

            // Fetch existing sightings to skip species already logged today
            let existing = (try? DatabaseManager.shared.getAllSightings()) ?? []
            let cutoff = Date().addingTimeInterval(-86400)
            let recentSpecies = Set(
                existing
                    .filter { $0.recordedAt > cutoff }
                    .map { $0.speciesName.lowercased() }
            )

            let audioPath = self.persistAudioFile(from: capturedAudioURL)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let month = formatter.string(from: Date())

            var savedCount = 0
            for detection in selectedDetections {
                if recentSpecies.contains(detection.species.lowercased()) { continue }

                let newSighting = Sighting(
                    id:           UUID().uuidString,
                    speciesName:  detection.species,
                    lifeStage:    baseSighting.lifeStage,
                    callType:     baseSighting.callType,
                    rawResponse:  baseSighting.rawResponse,
                    audioPath:    audioPath,
                    latitude:     location?.coordinate.latitude,
                    longitude:    location?.coordinate.longitude,
                    recordedAt:   Date(),
                    confidence:   detection.confidence,
                    providerName: baseSighting.providerName
                )
                try? DatabaseManager.shared.insertSighting(newSighting)
                savedCount += 1
            }

            try? DatabaseManager.shared.upsertMonthlyScore(forMonth: month)
            NotificationCenter.default.post(name: .sightingSaved, object: nil)

            let skipped = selectedDetections.count - savedCount
            if skipped > 0 {
                self.saveMessage = "Saved \(savedCount) species · \(skipped) already logged today"
            } else {
                self.saveMessage = "Saved \(savedCount) \(savedCount == 1 ? "species" : "species")"
            }
            self.showSaveConfirmation = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.reset()
                self.showSaveConfirmation = false
            }
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        audioFileURL = nil
        state = .idle
        elapsedSeconds = 0
        detectedSpecies = []
        showSaveConfirmation = false
    }

    // MARK: - Private

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
        audioFileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey:              Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:            16000.0,
            AVNumberOfChannelsKey:      1,
            AVEncoderAudioQualityKey:   AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey:        32000
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            elapsedSeconds = 0
            state = .recording

            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.elapsedSeconds += 1
                    if self.elapsedSeconds >= 30 { self.stopRecording() }
                }
            }
        } catch {
            state = .error("Could not start recording: \(error.localizedDescription)")
        }
    }

    private func identify() async {
        guard let url = audioFileURL else {
            state = .error("Audio file missing.")
            return
        }
        state = .loading
        do {
            let result = try await AudioIdentificationService.identify(audioURL: url)

            // Populate the selectable species list
            if result.allDetections.isEmpty {
                detectedSpecies = [DetectedSpecies(
                    species:        result.species,
                    scientificName: "",
                    confidence:     result.confidence,
                    isSelected:     true
                )]
            } else {
                detectedSpecies = result.allDetections
            }

            let sighting = Sighting(
                id:           UUID().uuidString,
                speciesName:  result.species,
                lifeStage:    result.lifeStage,
                callType:     result.callType,
                rawResponse:  result.rawResponse,
                audioPath:    url.path,
                latitude:     LocationService.shared.lastLocation?.coordinate.latitude,
                longitude:    LocationService.shared.lastLocation?.coordinate.longitude,
                recordedAt:   Date(),
                confidence:   result.confidence,
                providerName: result.providerName
            )
            state = .result(sighting)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Copies the temp recording to Documents/recordings/ so it persists between launches.
    private func persistAudioFile(from tempURL: URL?) -> String {
        guard let tempURL = tempURL,
              FileManager.default.fileExists(atPath: tempURL.path) else { return "" }
        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        let ext  = tempURL.pathExtension.isEmpty ? "m4a" : tempURL.pathExtension
        let dest = recordingsDir.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try? FileManager.default.copyItem(at: tempURL, to: dest)
        return dest.path
    }
}

// Equatable conformance (needed for animation value binding)
extension RecordViewModel.State: Equatable {
    static func == (lhs: RecordViewModel.State, rhs: RecordViewModel.State) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.loading, .loading): return true
        case (.result, .result):                                              return true
        case (.error(let l), .error(let r)):                                  return l == r
        default:                                                              return false
        }
    }
}
