import Foundation

struct BirdNETProvider: AudioIdentificationProvider {

    var name: String { "BirdNET (Cornell Lab)" }

    private let baseURL = "https://ippili7-gardenear-api.hf.space"

    func identify(audioURL: URL) async throws -> IdentificationResult {
        // Short-circuit immediately when offline — no TCP attempt needed
        let isOnline = await MainActor.run { NetworkMonitor.shared.isConnected }
        guard isOnline else {
            let hasLocal = await MainActor.run { OfflineModelManager.shared.isBirdNetDownloaded }
            if hasLocal {
                return try await BirdNETLocalProvider().identify(audioURL: audioURL)
            } else {
                throw AppError.offlineNoModel
            }
        }

        // Build URL — append GPS coordinates when available
        var urlString = "\(baseURL)/analyze"
        let lastLocation = await MainActor.run { LocationService.shared.lastLocation }
        if let location = lastLocation {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            urlString += "?lat=\(lat)&lon=\(lon)"
        }
        guard let url = URL(string: urlString) else {
            throw AppError.message("Invalid server URL")
        }

        let audioData = try Data(contentsOf: audioURL)

        // Build multipart/form-data body
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        let filename = audioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError
            where urlError.code == .notConnectedToInternet
               || urlError.code == .networkConnectionLost {
            // No connectivity — try local model if available, otherwise surface offline prompt
            let hasLocalModel = await MainActor.run { OfflineModelManager.shared.isBirdNetDownloaded }
            if hasLocalModel {
                return try await BirdNETLocalProvider().identify(audioURL: audioURL)
            } else {
                throw AppError.offlineNoModel
            }
        } catch let urlError as URLError
            where urlError.code == .timedOut
               || urlError.code == .cannotConnectToHost {
            throw AppError.message("Server is waking up. Wait 30 seconds and try again.")
        }

        let http = response as! HTTPURLResponse
        let rawBody = String(data: data, encoding: .utf8) ?? "unreadable"

        print("[BirdNET] Status: \(http.statusCode)")
        print("[BirdNET] Body: \(rawBody)")

        switch http.statusCode {
        case 200: break
        case 404: throw AppError.message("No species detected. Try recording closer to the sound.")
        default:  throw AppError.message("Server error \(http.statusCode). Try again.")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.message("No species detected. Try recording closer to the sound.")
        }

        // Top result fields
        let topSpecies    = json["species"]    as? String ?? json["label"]    as? String ?? "Unknown"
        let confidence    = json["confidence"] as? Double ?? json["score"]    as? Double ?? 0.0
        let lifeStage     = json["life_stage"] as? String ?? "Unknown"
        let callType      = json["call_type"]  as? String ?? "Unknown"

        // Parse all_detections — deduplicate by lowercased species name
        var allDetections: [DetectedSpecies] = []
        if let allArray = json["all_detections"] as? [[String: Any]] {
            var seen = Set<String>()
            for item in allArray {
                guard let species    = item["species"]    as? String,
                      let conf       = item["confidence"] as? Double,
                      !seen.contains(species.lowercased()) else { continue }
                seen.insert(species.lowercased())
                let scientific = item["scientific_name"] as? String ?? ""
                allDetections.append(DetectedSpecies(
                    species:        species,
                    scientificName: scientific,
                    confidence:     conf,
                    isSelected:     true
                ))
            }
        }

        // Fall back to a single entry when the server returns no list
        if allDetections.isEmpty {
            allDetections = [DetectedSpecies(
                species:        topSpecies,
                scientificName: json["scientific_name"] as? String ?? "",
                confidence:     confidence,
                isSelected:     true
            )]
        }

        return IdentificationResult(
            species:       topSpecies,
            lifeStage:     lifeStage,
            callType:      callType,
            confidence:    confidence,
            rawResponse:   rawBody,
            providerName:  name,
            allDetections: allDetections
        )
    }
}
