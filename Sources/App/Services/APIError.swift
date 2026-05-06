import Foundation

enum APIError: LocalizedError {
    case imageEncodingFailed
    case parsingFailed
    case missingAPIKey
    case missingAccountId
    case httpError(statusCode: Int, body: String)
    case noModelsAvailable

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "Failed to encode image"
        case .parsingFailed: return "Failed to parse API response"
        case .missingAPIKey: return "API key not configured"
        case .missingAccountId: return "Cloudflare Account ID not configured"
        case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(200))"
        case .noModelsAvailable: return "No models available for selected provider"
        }
    }
}
