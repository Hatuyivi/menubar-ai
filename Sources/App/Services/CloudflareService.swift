import Foundation
import AppKit

struct CloudflareService {
    private let apiKey: String
    private let accountId: String
    private let modelId: String

    init(apiKey: String, accountId: String, modelId: String) {
        self.apiKey = apiKey
        self.accountId = accountId
        self.modelId = modelId
    }

    // MARK: - Image to Text (OCR) — LLaVA / UForm style

    func recognizeNumbers(in image: NSImage, prompt: String = "Extract and list all numbers visible in this image. Return only the numbers found, separated by spaces.") async throws -> String {
        guard let imageData = image.pngData() else { throw APIError.imageEncodingFailed }

        let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountId)/ai/run/\(modelId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let base64 = imageData.base64EncodedString()
        let body: [String: Any] = [
            "prompt": prompt,
            "image": Array(imageData)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = json?["result"] as? [String: Any]
        return result?["description"] as? String ?? result?["response"] as? String ?? ""
    }

    // MARK: - Floor plan room detection

    func detectRooms(in image: NSImage) async throws -> [RoomSegment] {
        let prompt = """
        Analyze this floor plan image. Identify all distinct rooms/spaces.
        Return ONLY valid JSON in this exact format, no markdown:
        {"rooms":[{"label":"Room Name","x":0.1,"y":0.2,"width":0.3,"height":0.25,"colorHex":null}]}
        Use x,y,width,height as fractions of the image (0.0 to 1.0).
        """
        guard let imageData = image.pngData() else { throw APIError.imageEncodingFailed }

        let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountId)/ai/run/\(modelId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "image": Array(imageData)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = json?["result"] as? [String: Any]
        let text = result?["description"] as? String ?? result?["response"] as? String ?? ""
        return try parseRooms(from: text)
    }

    // MARK: - Image to Image (for Stable Diffusion models)

    func processFloorPlanImage(image: NSImage, prompt: String) async throws -> NSImage? {
        guard let imageData = image.pngData() else { throw APIError.imageEncodingFailed }
        let base64 = imageData.base64EncodedString()

        let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountId)/ai/run/\(modelId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "image": base64,
            "strength": 0.5
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data)

        return NSImage(data: data)
    }

    // MARK: - Helpers

    private func parseRooms(from text: String) throws -> [RoomSegment] {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.range(of: "{") { cleaned = String(cleaned[start.lowerBound...]) }
        if let end = cleaned.range(of: "}", options: .backwards) { cleaned = String(cleaned[...end.upperBound]) }
        guard let data = cleaned.data(using: .utf8) else { throw APIError.parsingFailed }
        return try JSONDecoder().decode(FloorPlanAPIResponse.self, from: data).rooms
    }

    private func checkHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode >= 400 else { return }
        let body = String(data: data, encoding: .utf8) ?? "unknown"
        throw APIError.httpError(statusCode: http.statusCode, body: body)
    }
}
