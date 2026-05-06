import SwiftUI

// MARK: - Provider Selector

struct ProviderSelector: View {
    @Binding var selectedProvider: APIProvider
    let onSelect: (APIProvider) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Provider")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(APIProvider.allCases) { provider in
                    ProviderChip(provider: provider, isSelected: selectedProvider == provider) {
                        selectedProvider = provider
                        onSelect(provider)
                    }
                }
            }
        }
    }
}

struct ProviderChip: View {
    let provider: APIProvider
    let isSelected: Bool
    let onTap: () -> Void

    private var icon: String {
        switch provider {
        case .gemini: return "sparkles"
        case .openRouter: return "arrow.triangle.branch"
        case .cloudflare: return "cloud"
        }
    }

    private var color: Color {
        switch provider {
        case .gemini: return .blue
        case .openRouter: return .purple
        case .cloudflare: return .orange
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(provider.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? color : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Picker

struct ModelPickerView: View {
    let models: [AIModel]
    @Binding var selectedModel: AIModel?
    let provider: APIProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            if models.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("No models available — add an API key in Settings")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.2)))
                .cornerRadius(6)
            } else {
                Picker("", selection: $selectedModel) {
                    ForEach(models) { model in
                        Text(model.name).tag(Optional(model))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: models) { newModels in
                    if let current = selectedModel, !newModels.contains(current) {
                        selectedModel = newModels.first
                    }
                }

                if let model = selectedModel {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Free tier · \(model.id)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
