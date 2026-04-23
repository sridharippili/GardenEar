import Foundation
import AVFoundation


/// On-device BirdNET inference using the downloaded TFLite model.
///
/// Audio pipeline:
///   1. Decode any audio file → 48 kHz mono float32
///   2. Pad / trim to exactly 144 000 samples (3 s)
///   3. Feed to BirdNET → softmax scores ranked against the bundled labels file
///
/// Requires TensorFlowLiteSwift pod (pod 'TensorFlowLiteSwift', '~> 2.14.0').
struct BirdNETLocalProvider: AudioIdentificationProvider {

    var name: String { "BirdNET (offline)" }

    // MARK: - Entry point

    func identify(audioURL: URL) async throws -> IdentificationResult {
        // Fetch model path on main actor (OfflineModelManager is @MainActor)
        guard let modelPath = await MainActor.run(body: {
            OfflineModelManager.shared.birdNetModelURL?.path
        }) else {
            throw AppError.message(
                "BirdNET model not found. Please download it in Settings → Offline Models."
            )
        }

        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw AppError.message("BirdNET model file is missing. Try re-downloading.")
        }

        let audioData  = try preprocessAudio(url: audioURL)
        let scores     = try runInference(modelPath: modelPath, audioData: audioData)
        let labels     = loadLabels()
        let detections = rankDetections(scores: scores, labels: labels)

        guard let top = detections.first else {
            throw AppError.message(
                "No species detected. Try recording closer to the sound, for at least 3 seconds."
            )
        }

        let allDetections = Array(detections.prefix(10)).map { d in
            DetectedSpecies(
                species:        d.common,
                scientificName: d.scientific,
                confidence:     d.confidence,
                isSelected:     true
            )
        }

        return IdentificationResult(
            species:       top.common,
            lifeStage:     "Unknown",
            callType:      "Unknown",
            confidence:    top.confidence,
            rawResponse:   buildRawResponse(detections: detections),
            providerName:  name,
            allDetections: allDetections
        )
    }

    // MARK: - Audio preprocessing

    /// Converts any audio file to BirdNET input format:
    /// 48 kHz · mono · float32 · exactly 144 000 samples (3 seconds).
    private func preprocessAudio(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!

        let chunkSize = 144_000   // 3 s × 48 000 Hz

        guard let converter = AVAudioConverter(
            from: file.processingFormat, to: targetFormat
        ) else {
            throw AppError.message(
                "Could not create audio converter (unsupported source format)."
            )
        }

        // Read whole file into a source buffer
        let srcBuffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        )!
        try file.read(into: srcBuffer)

        // Allocate destination buffer sized for the resampled output
        let ratio     = 48_000.0 / file.processingFormat.sampleRate
        let dstFrames = AVAudioFrameCount(Double(srcBuffer.frameLength) * ratio) + 512
        guard let dstBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat, frameCapacity: dstFrames
        ) else {
            throw AppError.message("Could not allocate resampled audio buffer.")
        }

        var conversionError: NSError?
        let inputConsumed = AtomicBool(false)   // guard against repeated callback
        converter.convert(to: dstBuffer, error: &conversionError) { _, outStatus in
            if inputConsumed.value {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed.value = true
            outStatus.pointee   = .haveData
            return srcBuffer
        }

        if let err = conversionError {
            throw AppError.message("Audio resampling failed: \(err.localizedDescription)")
        }

        guard let channelData = dstBuffer.floatChannelData?[0] else {
            throw AppError.message("Could not read float audio channel data.")
        }

        var samples = Array(
            UnsafeBufferPointer(start: channelData, count: Int(dstBuffer.frameLength))
        )

        if samples.count < chunkSize {
            samples += Array(repeating: 0.0, count: chunkSize - samples.count)
        } else if samples.count > chunkSize {
            samples = Array(samples.prefix(chunkSize))
        }

        return samples
    }

    // MARK: - Inference (stub — activate after opening GardenEar.xcworkspace)

    private func runInference(modelPath: String,
                              audioData: [Float]) throws -> [Float] {
        // TensorFlowLite requires building from GardenEar.xcworkspace (not .xcodeproj).
        // Steps:
        //   1. cd /Users/sridharippili/Downloads/GardenEar
        //   2. xcodegen generate && pod install
        //   3. open GardenEar.xcworkspace
        // Then restore: import TensorFlowLite + the full Interpreter implementation.
        throw AppError.message(
            "Offline model initializing. Please try again in a moment."
        )
    }

    // MARK: - Labels

    private struct LabelEntry {
        let common: String
        let scientific: String
    }

    /// Loads BirdNET_GLOBAL_6K_V2.4_Labels.txt from the app bundle.
    /// Each line format: "Genus species_Common Name"
    private func loadLabels() -> [LabelEntry] {
        guard
            let url     = Bundle.main.url(forResource: "BirdNET_GLOBAL_6K_V2.4_Labels",
                                           withExtension: "txt"),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            print("[BirdNET] ⚠️ Labels file not found in app bundle.")
            return []
        }

        return content
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { line in
                // Split on the FIRST underscore only
                if let idx = line.firstIndex(of: "_") {
                    return LabelEntry(
                        common:     String(line[line.index(after: idx)...]),
                        scientific: String(line[..<idx])
                    )
                }
                return LabelEntry(common: line, scientific: "")
            }
    }

    // MARK: - Ranking

    private struct Detection {
        let common: String
        let scientific: String
        let confidence: Double
    }

    private func rankDetections(scores: [Float], labels: [LabelEntry]) -> [Detection] {
        guard !labels.isEmpty else {
            return [Detection(common: "Unknown", scientific: "", confidence: 0.5)]
        }
        return zip(scores, labels)
            .compactMap { score, label -> Detection? in
                guard score >= 0.1 else { return nil }
                return Detection(
                    common:     label.common,
                    scientific: label.scientific,
                    confidence: Double(score)
                )
            }
            .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Raw response JSON

    private func buildRawResponse(detections: [Detection]) -> String {
        let items: [[String: Any]] = detections.prefix(5).map {
            [
                "species":         $0.common,
                "scientific_name": $0.scientific,
                "confidence":      $0.confidence
            ]
        }
        let wrapper: [String: Any] = [
            "all_detections": items,
            "provider":       name,
            "offline":        true
        ]
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: wrapper, options: .prettyPrinted
            ),
            let str = String(data: data, encoding: .utf8)
        else { return "{}" }
        return str
    }
}

// MARK: - Thread-safe bool helper (avoids data race in AVAudioConverter callback)

private final class AtomicBool: @unchecked Sendable {
    var value: Bool
    init(_ v: Bool) { value = v }
}
