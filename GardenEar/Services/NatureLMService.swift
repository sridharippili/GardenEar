import Foundation

struct NatureLMService {

    static func identify(audioURL: URL) async throws -> (
        species: String, lifeStage: String, callType: String, raw: String
    ) {
        guard let token = Bundle.main.infoDictionary?["HF_TOKEN"] as? String,
              !token.isEmpty else {
            throw NSError(domain: "NatureLM", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "HF_TOKEN not found in Info.plist"])
        }

        let audioData = try Data(contentsOf: audioURL)

        let url = URL(string: "https://router.huggingface.co/hf-inference/models/EarthSpeciesProject/NatureLM-audio")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        let bodyString = String(data: data, encoding: .utf8) ?? "unreadable"

        print("[NatureLM] Status: \(httpResponse.statusCode)")
        print("[NatureLM] Body: \(bodyString)")

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw NSError(domain: "NatureLM", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Hugging Face token. Check Info.plist HF_TOKEN value."])
        case 403:
            throw NSError(domain: "NatureLM", code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Access denied. Accept the model license at huggingface.co/EarthSpeciesProject/NatureLM-audio"])
        case 503:
            throw NSError(domain: "NatureLM", code: 503,
                userInfo: [NSLocalizedDescriptionKey: "Model is loading. Wait 20 seconds and try again."])
        default:
            throw NSError(domain: "NatureLM", code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "API error \(httpResponse.statusCode): \(bodyString.prefix(200))"])
        }

        // Parse JSON array response: [{"label": "Robin", "score": 0.94}, ...]
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let top = jsonArray.first,
           let label = top["label"] as? String {
            return (species: label, lifeStage: "Unknown", callType: "Unknown", raw: bodyString)
        }

        // Parse single object response: {"label": "Robin", "score": 0.94}
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let label = jsonObject["label"] as? String {
            return (species: label, lifeStage: "Unknown", callType: "Unknown", raw: bodyString)
        }

        // Fallback: return raw string if parsing fails
        if !bodyString.isEmpty && bodyString != "unreadable" {
            return (species: bodyString, lifeStage: "Unknown", callType: "Unknown", raw: bodyString)
        }

        throw NSError(domain: "NatureLM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "No species detected. Try recording closer to the sound."])
    }

    // MARK: - Debug

    static func testAPIConnection() async {
        guard let token = Bundle.main.infoDictionary?["HF_TOKEN"] as? String else {
            print("❌ HF_TOKEN not found in Info.plist")
            return
        }
        print("✅ Token found: \(token.prefix(8))...")

        let url = URL(string: "https://router.huggingface.co/hf-inference/models/EarthSpeciesProject/NatureLM-audio")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as! HTTPURLResponse
            let body = String(data: data, encoding: .utf8) ?? "unreadable"
            print("📡 Status code: \(httpResponse.statusCode)")
            print("📦 Response body: \(body)")
        } catch {
            print("💥 Network error: \(error)")
        }
    }
}
