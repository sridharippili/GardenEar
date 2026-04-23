import Foundation

struct NatureLMProvider: AudioIdentificationProvider {

    var name: String { "NatureLM-audio" }

    private let routerURL = "https://gardenear-router.onrender.com"

    func identify(audioURL: URL) async throws -> IdentificationResult {
        // Check connectivity
        let isOnline = await MainActor.run { NetworkMonitor.shared.isConnected }
        guard isOnline else {
            throw AppError.offlineNoModel
        }

        // Check router has active providers
        if let healthURL = URL(string: "\(routerURL)/health"),
           let (healthData, _) = try? await URLSession.shared.data(from: healthURL),
           let json = try? JSONSerialization.jsonObject(with: healthData) as? [String: Any],
           let providers = json["active_providers"] as? [String],
           providers.isEmpty {
            throw AppError.message("NatureLM is not running. Start Kaggle notebook first.")
        }

        // Build multipart request
        let audioData = try Data(contentsOf: audioURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        let filename = audioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var components = URLComponents(string: "\(routerURL)/identify")!
        components.queryItems = [
            URLQueryItem(
                name: "query",
                value: "What is the common name of the bird species in this audio? Answer:"
            )
        ]
        guard let url = components.url else {
            throw AppError.message("Invalid router URL")
        }
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
            throw AppError.offlineNoModel
        } catch let urlError as URLError
            where urlError.code == .timedOut
               || urlError.code == .cannotConnectToHost {
            throw AppError.message("NatureLM timed out. Try again.")
        }

        let http = response as! HTTPURLResponse
        let rawBody = String(data: data, encoding: .utf8) ?? "unreadable"

        print("[NatureLM] Status: \(http.statusCode)")
        print("[NatureLM] Body: \(rawBody)")

        guard http.statusCode == 200 else {
            throw AppError.message("NatureLM error \(http.statusCode). Try again.")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.message("Could not parse NatureLM response.")
        }

        // Parse result — format is "#0.00s - 10.00s#: Laughing Kookaburra\n"
        let rawResult = json["result"] as? String ?? ""
        let via = json["via"] as? String ?? "naturelm"

        // Strip the "#0.00s - 10.00s#: " timestamp prefix, keep only the common name
        var species = rawResult
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let tsRange = species.range(of: #"^#[^#]+#:\s*"#, options: .regularExpression) {
            // Matched "#...#: " at the start — drop it
            species = String(species[tsRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
        } else if let colonRange = species.range(of: ": ") {
            // Fallback: strip anything before the first ": "
            species = String(species[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
        }

        let detection = DetectedSpecies(
            species: species,
            scientificName: "",
            confidence: 1.0,
            isSelected: true
        )

        return IdentificationResult(
            species: species,
            lifeStage: "Unknown",
            callType: "Unknown",
            confidence: 1.0,
            rawResponse: rawBody,
            providerName: "\(name) via \(via)",
            allDetections: [detection]
        )
    }
}
