import Foundation
import AppKit

struct GeminiService {
    private let apiKey: String
    private let modelId: String

    init(apiKey: String, modelId: String) {
        self.apiKey = apiKey
        self.modelId = modelId
    }

    // MARK: - Image to Text (OCR)

    func recognizeNumbers(in image: NSImage, prompt: String = "Extract and list all numbers visible in this image. Return only the numbers found, separated by spaces.") async throws -> String {
        guard let base64 = image.pngBase64() else { throw APIError.imageEncodingFailed }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/png", "data": base64]]
                ]
            ]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return extractGeminiText(json) ?? ""
    }

    // MARK: - Floor plan room detection

    func detectRooms(in image: NSImage) async throws -> [RoomSegment] {
        guard let base64 = image.pngBase64() else { throw APIError.imageEncodingFailed }

        let prompt = """
        Analyze this floor plan image. Identify all distinct rooms/spaces.
        Return ONLY valid JSON in this exact format, no markdown:
        {"rooms":[{"label":"Room Name","x":0.1,"y":0.2,"width":0.3,"height":0.25,"colorHex":null}]}
        Use x,y,width,height as fractions of the image (0.0 to 1.0). Include all rooms you can see.
        """

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/png", "data": base64]]
                ]
            ]],
            "generationConfig": ["temperature": 0]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let text = extractGeminiText(json) ?? ""
        return try parseRooms(from: text)
    }

    // MARK: - Helpers

    private func extractGeminiText(_ json: [String: Any]?) -> String? {
        guard
            let candidates = json?["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else { return nil }
        return text
    }

    private func parseRooms(from text: String) throws -> [RoomSegment] {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.range(of: "{") {
            cleaned = String(cleaned[start.lowerBound...])
        }
        if let end = cleaned.range(of: "}", options: .backwards) {
            cleaned = String(cleaned[...end.upperBound])
        }
        guard let data = cleaned.data(using: .utf8) else { throw APIError.parsingFailed }
        let decoded = try JSONDecoder().decode(FloorPlanAPIResponse.self, from: data)
        return decoded.rooms
    }

    private func checkHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}
