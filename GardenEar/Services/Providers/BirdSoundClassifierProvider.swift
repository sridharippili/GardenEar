import Foundation

struct BirdSoundClassifierProvider: AudioIdentificationProvider {

    var name: String { "dima806/bird_sounds_classification" }

    func identify(audioURL: URL) async throws -> IdentificationResult {
        guard let token = Bundle.main.infoDictionary?["HF_TOKEN"] as? String,
              !token.isEmpty else {
            throw AppError.message("HF_TOKEN not found in Info.plist")
        }

        let audioData = try Data(contentsOf: audioURL)
        let url = URL(string: "https://router.huggingface.co/hf-inference/models/dima806/bird_sounds_classification")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        let body = String(data: data, encoding: .utf8) ?? "unreadable"

        print("[BirdSoundClassifier] Status: \(http.statusCode)")
        print("[BirdSoundClassifier] Body: \(body)")

        switch http.statusCode {
        case 200: break
        case 401: throw AppError.message("Invalid token. Check HF_TOKEN in Info.plist.")
        case 403: throw AppError.message("Access denied. Check your Hugging Face account.")
        case 503: throw AppError.message("Model is loading. Wait 20 seconds and try again.")
        default:  throw AppError.message("API error \(http.statusCode). Check Xcode console.")
        }

        // Parse [{"label": "American Robin", "score": 0.94}, ...]
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let top = array.first,
           let label = top["label"] as? String {
            let score = top["score"] as? Double ?? 0
            return IdentificationResult(
                species:       label,
                lifeStage:     "Unknown",
                callType:      "Unknown",
                confidence:    score,
                rawResponse:   body,
                providerName:  name,
                allDetections: []   // single-result provider
            )
        }

        throw AppError.message("Could not identify species. Try recording closer to the sound.")
    }
}
