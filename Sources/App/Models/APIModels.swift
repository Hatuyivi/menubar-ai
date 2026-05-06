import Foundation
import AppKit

// MARK: - API Provider

enum APIProvider: String, CaseIterable, Codable, Identifiable {
    case gemini = "Gemini"
    case openRouter = "OpenRouter"
    case cloudflare = "Cloudflare"

    var id: String { rawValue }
}

// MARK: - Module type determines which model categories to show

enum ModuleType {
    case ocr        // image → text  (Module 1)
    case floorPlan  // image+text → structured JSON (Module 2, also vision models)
}

// MARK: - Model descriptor

struct AIModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: APIProvider
    let supportsVision: Bool     // can receive an image + return text
    let isFreeTier: Bool
}

// MARK: - Free-tier model registry

enum ModelRegistry {

    // MARK: Gemini free models (all support vision)
    static let geminiModels: [AIModel] = [
        AIModel(id: "gemini-2.0-flash",      name: "Gemini 2.0 Flash",      provider: .gemini, supportsVision: true, isFreeTier: true),
        AIModel(id: "gemini-2.0-flash-lite", name: "Gemini 2.0 Flash Lite", provider: .gemini, supportsVision: true, isFreeTier: true),
        AIModel(id: "gemini-1.5-flash",      name: "Gemini 1.5 Flash",      provider: .gemini, supportsVision: true, isFreeTier: true),
        AIModel(id: "gemini-1.5-flash-8b",   name: "Gemini 1.5 Flash 8B",   provider: .gemini, supportsVision: true, isFreeTier: true),
    ]

    // MARK: OpenRouter free vision models (":free" suffix = free tier)
    static let openRouterModels: [AIModel] = [
        AIModel(id: "google/gemini-2.0-flash-exp:free",                    name: "Gemini 2.0 Flash Exp (free)",       provider: .openRouter, supportsVision: true, isFreeTier: true),
        AIModel(id: "google/gemini-flash-1.5:free",                        name: "Gemini Flash 1.5 (free)",           provider: .openRouter, supportsVision: true, isFreeTier: true),
        AIModel(id: "meta-llama/llama-3.2-90b-vision-instruct:free",       name: "Llama 3.2 90B Vision (free)",       provider: .openRouter, supportsVision: true, isFreeTier: true),
        AIModel(id: "meta-llama/llama-3.2-11b-vision-instruct:free",       name: "Llama 3.2 11B Vision (free)",       provider: .openRouter, supportsVision: true, isFreeTier: true),
        AIModel(id: "qwen/qwen2-vl-72b-instruct:free",                     name: "Qwen2 VL 72B (free)",               provider: .openRouter, supportsVision: true, isFreeTier: true),
        AIModel(id: "qwen/qwen2-vl-7b-instruct:free",                      name: "Qwen2 VL 7B (free)",                provider: .openRouter, supportsVision: true, isFreeTier: true),
    ]

    // MARK: Cloudflare Workers AI — confirmed vision models (accept image + text → return text)
    static let cloudflareModels: [AIModel] = [
        AIModel(id: "@cf/meta/llama-4-scout-17b-16e-instruct",     name: "Llama 4 Scout 17B",       provider: .cloudflare, supportsVision: true, isFreeTier: true),
        AIModel(id: "@cf/meta/llama-3.2-11b-vision-instruct",      name: "Llama 3.2 11B Vision",    provider: .cloudflare, supportsVision: true, isFreeTier: true),
        AIModel(id: "@cf/google/gemma-4-26b-a4b-it",               name: "Gemma 4 26B",             provider: .cloudflare, supportsVision: true, isFreeTier: true),
        AIModel(id: "@cf/mistralai/mistral-small-3.1-24b-instruct", name: "Mistral Small 3.1 24B",  provider: .cloudflare, supportsVision: true, isFreeTier: true),
        AIModel(id: "@cf/llava-hf/llava-1.5-7b-hf",               name: "LLaVA 1.5 7B",            provider: .cloudflare, supportsVision: true, isFreeTier: true),
        AIModel(id: "@cf/zai-org/glm-4.7-flash",                   name: "GLM 4.7 Flash",           provider: .cloudflare, supportsVision: true, isFreeTier: true),
        AIModel(id: "@cf/unum/uform-gen2-qwen-500m",               name: "UForm Gen2 Qwen 500M",    provider: .cloudflare, supportsVision: true, isFreeTier: true),
    ]

    static func models(for provider: APIProvider, moduleType: ModuleType) -> [AIModel] {
        let all: [AIModel]
        switch provider {
        case .gemini:      all = geminiModels
        case .openRouter:  all = openRouterModels
        case .cloudflare:  all = cloudflareModels
        }
        // Both modules need vision capability — only difference is the prompt used
        return all.filter { $0.supportsVision && $0.isFreeTier }
    }
}

// MARK: - API Keys (stored in Keychain)

struct APIKeys {
    static func key(for provider: APIProvider) -> String? {
        KeychainHelper.load(key: provider.rawValue)
    }
    static func set(key: String, for provider: APIProvider) {
        KeychainHelper.save(key: provider.rawValue, value: key)
    }
    static func delete(for provider: APIProvider) {
        KeychainHelper.delete(key: provider.rawValue)
    }
    static func hasKey(for provider: APIProvider) -> Bool {
        guard let k = key(for: provider) else { return false }
        return !k.isEmpty
    }
}

// MARK: - Room collider from floor plan

struct RoomCollider: Identifiable {
    let id: UUID
    var rect: CGRect
    var color: NSColor
    var label: String
    var isSelected: Bool

    init(id: UUID = .init(), rect: CGRect, color: NSColor, label: String, isSelected: Bool = true) {
        self.id = id; self.rect = rect; self.color = color; self.label = label; self.isSelected = isSelected
    }
}

// MARK: - Floor plan segment from API

struct RoomSegment: Codable {
    let label: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let colorHex: String?
}

struct FloorPlanAPIResponse: Codable {
    let rooms: [RoomSegment]
}
