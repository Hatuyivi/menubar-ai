import SwiftUI
import AppKit

class Module1ViewModel: ObservableObject {
    @Published var selectedProvider: APIProvider = .gemini
    @Published var selectedModel: AIModel?
    @Published var capturedImage: NSImage?
    @Published var result: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var prompt: String = "Extract and list all numbers visible in this image. Return only the numbers found, separated by spaces."

    // Strong reference — prevents ARC from releasing the window while it's shown
    private var selectorWindow: ScreenSelectorWindow?

    var availableModels: [AIModel] {
        guard APIKeys.hasKey(for: selectedProvider) else { return [] }
        if selectedProvider == .cloudflare && !hasCloudflareAccountId { return [] }
        return ModelRegistry.models(for: selectedProvider, moduleType: .ocr)
    }

    var hasCloudflareAccountId: Bool {
        guard let id = UserDefaults.standard.string(forKey: "cloudflare_account_id") else { return false }
        return !id.isEmpty
    }

    func selectProvider(_ provider: APIProvider) {
        selectedProvider = provider
        selectedModel = availableModels.first
        result = ""
        errorMessage = nil
    }

    func captureScreen() {
        capturedImage = nil
        result = ""
        errorMessage = nil

        // Close the menubar popover so it doesn't appear in the screenshot
        (NSApp.delegate as? AppDelegate)?.closePopover()

        // Brief delay to let the popover fully close before showing overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }

            let window = ScreenSelectorWindow()
            // Keep strong reference so ARC doesn't release the window
            self.selectorWindow = window

            window.onCapture = { [weak self] image in
                DispatchQueue.main.async {
                    self?.capturedImage = image
                    self?.selectorWindow = nil  // Release after capture
                    // Re-open the popover
                    (NSApp.delegate as? AppDelegate)?.openPopover()
                }
            }
            window.onCancel = { [weak self] in
                DispatchQueue.main.async {
                    self?.selectorWindow = nil
                    (NSApp.delegate as? AppDelegate)?.openPopover()
                }
            }

            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        }
    }

    func recognize() async {
        guard let image = capturedImage, let model = selectedModel else { return }
        guard let apiKey = APIKeys.key(for: selectedProvider) else {
            await MainActor.run { errorMessage = "API key not set. Go to Settings." }
            return
        }

        await MainActor.run { isLoading = true; errorMessage = nil; result = "" }

        do {
            let text: String
            switch selectedProvider {
            case .gemini:
                let service = GeminiService(apiKey: apiKey, modelId: model.id)
                text = try await service.recognizeNumbers(in: image, prompt: prompt)
            case .openRouter:
                let service = OpenRouterService(apiKey: apiKey, modelId: model.id)
                text = try await service.recognizeNumbers(in: image, prompt: prompt)
            case .cloudflare:
                let accountId = UserDefaults.standard.string(forKey: "cloudflare_account_id") ?? ""
                let service = CloudflareService(apiKey: apiKey, accountId: accountId, modelId: model.id)
                text = try await service.recognizeNumbers(in: image, prompt: prompt)
            }
            await MainActor.run { result = text }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }

        await MainActor.run { isLoading = false }
    }
}

struct Module1View: View {
    @StateObject private var vm = Module1ViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                ProviderSelector(
                    selectedProvider: $vm.selectedProvider,
                    onSelect: vm.selectProvider
                )

                ModelPickerView(
                    models: vm.availableModels,
                    selectedModel: $vm.selectedModel,
                    provider: vm.selectedProvider
                )

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("Prompt", systemImage: "text.bubble")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextEditor(text: $vm.prompt)
                        .font(.system(size: 12))
                        .frame(height: 52)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        .cornerRadius(6)
                }

                Divider()

                Button(action: vm.captureScreen) {
                    Label("Select Screen Area", systemImage: "viewfinder.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.selectedModel == nil)
                .help(vm.selectedModel == nil ? "Configure an API key first" : "Click and drag to select a screen area")

                if let image = vm.capturedImage {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Captured", systemImage: "photo")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 140)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

                        Button(action: { Task { await vm.recognize() } }) {
                            Group {
                                if vm.isLoading {
                                    HStack { ProgressView().scaleEffect(0.7); Text("Recognizing…") }
                                } else {
                                    Label("Recognize Numbers", systemImage: "wand.and.stars")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isLoading)
                    }
                }

                if !vm.result.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Result", systemImage: "checkmark.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(vm.result, forType: .string)
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                        Text(vm.result)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.06))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }

                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06))
                        .cornerRadius(8)
                }
            }
            .padding(16)
        }
        .onAppear { vm.selectedModel = vm.availableModels.first }
    }
}
