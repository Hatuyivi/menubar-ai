import SwiftUI

struct SettingsView: View {
    @State private var geminiKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var cloudflareKey: String = ""
    @State private var cloudflareAccountId: String = ""
    @State private var savedIndicator: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text("API Keys are stored securely in macOS Keychain.\nOnly providers with a valid key show available models.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                // Gemini
                APIKeySection(
                    title: "Gemini",
                    icon: "sparkles",
                    color: .blue,
                    description: "Free tier: 1,500 req/day on Flash models",
                    linkTitle: "aistudio.google.com",
                    linkURL: "https://aistudio.google.com/apikey",
                    value: $geminiKey,
                    onSave: { saveKey(geminiKey, for: .gemini) },
                    onClear: { clearKey(for: .gemini) }
                )

                // OpenRouter
                APIKeySection(
                    title: "OpenRouter",
                    icon: "arrow.triangle.branch",
                    color: .purple,
                    description: "Free models marked with :free suffix",
                    linkTitle: "openrouter.ai/keys",
                    linkURL: "https://openrouter.ai/keys",
                    value: $openRouterKey,
                    onSave: { saveKey(openRouterKey, for: .openRouter) },
                    onClear: { clearKey(for: .openRouter) }
                )

                // Cloudflare
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "cloud")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        Text("Cloudflare Workers AI")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Link("dash.cloudflare.com", destination: URL(string: "https://dash.cloudflare.com/profile/api-tokens")!)
                            .font(.system(size: 11))
                    }

                    Text("Free tier: 10,000 neurons/day")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account ID")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        SecureField("cf_xxxxxxxxxxxxxxxx", text: $cloudflareAccountId)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Token")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        SecureField("Enter Cloudflare API Token", text: $cloudflareKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    HStack {
                        Button("Save") {
                            UserDefaults.standard.set(cloudflareAccountId, forKey: "cloudflare_account_id")
                            saveKey(cloudflareKey, for: .cloudflare)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(cloudflareKey.isEmpty && cloudflareAccountId.isEmpty)

                        Button("Clear") { clearKey(for: .cloudflare); cloudflareAccountId = "" }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                if let msg = savedIndicator {
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                }

                Divider()

                // About
                VStack(alignment: .leading, spacing: 6) {
                    Text("About")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("MenuBar AI v1.0 — macOS 13+")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Module 1: Screen OCR (image → text models)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Module 2: Floor plan room detection (vision models)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .onAppear(perform: loadKeys)
    }

    private func loadKeys() {
        geminiKey = APIKeys.key(for: .gemini) ?? ""
        openRouterKey = APIKeys.key(for: .openRouter) ?? ""
        cloudflareKey = APIKeys.key(for: .cloudflare) ?? ""
        cloudflareAccountId = UserDefaults.standard.string(forKey: "cloudflare_account_id") ?? ""
    }

    private func saveKey(_ key: String, for provider: APIProvider) {
        if key.isEmpty { APIKeys.delete(for: provider) } else { APIKeys.set(key: key, for: provider) }
        savedIndicator = "Saved"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedIndicator = nil }
    }

    private func clearKey(for provider: APIProvider) {
        APIKeys.delete(for: provider)
        switch provider {
        case .gemini: geminiKey = ""
        case .openRouter: openRouterKey = ""
        case .cloudflare: cloudflareKey = ""
        }
        savedIndicator = "Cleared"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedIndicator = nil }
    }
}

struct APIKeySection: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let linkTitle: String
    let linkURL: String
    @Binding var value: String
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Link(linkTitle, destination: URL(string: linkURL)!)
                    .font(.system(size: 11))
            }

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            SecureField("Enter \(title) API Key", text: $value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            HStack {
                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(value.isEmpty)
                Button("Clear") { onClear() }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}
