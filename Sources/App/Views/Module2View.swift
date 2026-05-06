import SwiftUI
import AppKit
import UniformTypeIdentifiers

class Module2ViewModel: ObservableObject {
    @Published var selectedProvider: APIProvider = .gemini
    @Published var selectedModel: AIModel?
    @Published var floorPlanImage: NSImage?
    @Published var colliders: [RoomCollider] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var savedFloorPlans: [SavedFloorPlan] = []

    struct SavedFloorPlan: Identifiable, Codable {
        let id: UUID
        let name: String
        let date: Date
        let collidersData: Data
    }

    var availableModels: [AIModel] {
        guard APIKeys.hasKey(for: selectedProvider) else { return [] }
        if selectedProvider == .cloudflare && !hasCloudflareAccountId { return [] }
        return ModelRegistry.models(for: selectedProvider, moduleType: .floorPlan)
    }

    var hasCloudflareAccountId: Bool {
        guard let id = UserDefaults.standard.string(forKey: "cloudflare_account_id") else { return false }
        return !id.isEmpty
    }

    func selectProvider(_ provider: APIProvider) {
        selectedProvider = provider
        selectedModel = availableModels.first
        errorMessage = nil
    }

    func loadImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        floorPlanImage = NSImage(contentsOf: url)
        colliders = []
        errorMessage = nil
    }

    func detectRooms() async {
        guard let image = floorPlanImage, let model = selectedModel else { return }
        guard let apiKey = APIKeys.key(for: selectedProvider) else {
            await MainActor.run { errorMessage = "API key not set. Go to Settings." }
            return
        }

        await MainActor.run { isLoading = true; errorMessage = nil; colliders = [] }

        do {
            let segments: [RoomSegment]
            switch selectedProvider {
            case .gemini:
                segments = try await GeminiService(apiKey: apiKey, modelId: model.id).detectRooms(in: image)
            case .openRouter:
                segments = try await OpenRouterService(apiKey: apiKey, modelId: model.id).detectRooms(in: image)
            case .cloudflare:
                let accountId = UserDefaults.standard.string(forKey: "cloudflare_account_id") ?? ""
                segments = try await CloudflareService(apiKey: apiKey, accountId: accountId, modelId: model.id).detectRooms(in: image)
            }

            let palette = ColliderPalette.colors
            let imageSize = image.size
            let built: [RoomCollider] = segments.enumerated().map { i, seg in
                let color = palette[i % palette.count]
                let rect = CGRect(
                    x: seg.x * imageSize.width,
                    y: seg.y * imageSize.height,
                    width: seg.width * imageSize.width,
                    height: seg.height * imageSize.height
                )
                return RoomCollider(rect: rect, color: color, label: seg.label)
            }

            await MainActor.run { colliders = built }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }

        await MainActor.run { isLoading = false }
    }

    func saveSelected(name: String) {
        let selected = colliders.filter { $0.isSelected }
        guard !selected.isEmpty else { return }
        let data = (try? JSONEncoder().encode(selected.map { ColliderRecord(from: $0) })) ?? Data()
        let plan = SavedFloorPlan(id: UUID(), name: name, date: Date(), collidersData: data)
        savedFloorPlans.insert(plan, at: 0)
    }

    func deleteSaved(id: UUID) {
        savedFloorPlans.removeAll { $0.id == id }
    }
}

struct ColliderRecord: Codable {
    let label: String
    let x, y, width, height: Double
    let colorHex: String

    init(from c: RoomCollider) {
        label = c.label
        x = c.rect.minX; y = c.rect.minY
        width = c.rect.width; height = c.rect.height
        colorHex = c.color.hexString
    }
}

enum ColliderPalette {
    static let colors: [NSColor] = [
        NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 0.5),
        NSColor(red: 0.18, green: 0.55, blue: 0.94, alpha: 0.5),
        NSColor(red: 0.20, green: 0.74, blue: 0.42, alpha: 0.5),
        NSColor(red: 0.95, green: 0.65, blue: 0.18, alpha: 0.5),
        NSColor(red: 0.70, green: 0.30, blue: 0.90, alpha: 0.5),
        NSColor(red: 0.20, green: 0.80, blue: 0.85, alpha: 0.5),
        NSColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 0.5),
        NSColor(red: 0.40, green: 0.70, blue: 0.20, alpha: 0.5),
    ]
}

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }
}

// MARK: - Main Module2 View

struct Module2View: View {
    @StateObject private var vm = Module2ViewModel()
    @State private var showSaveSheet = false
    @State private var saveName = ""
    @State private var showSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                ProviderSelector(selectedProvider: $vm.selectedProvider, onSelect: vm.selectProvider)
                ModelPickerView(models: vm.availableModels, selectedModel: $vm.selectedModel, provider: vm.selectedProvider)

                Divider()

                // Load image
                HStack {
                    Button(action: vm.loadImage) {
                        Label("Load Floor Plan", systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)

                    if !vm.colliders.isEmpty {
                        Button(action: { showSaveSheet = true }) {
                            Label("Save Selected", systemImage: "square.and.arrow.down")
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.colliders.filter { $0.isSelected }.isEmpty)
                    }
                }

                // Floor plan canvas with colliders
                if let image = vm.floorPlanImage {
                    FloorPlanCanvas(image: image, colliders: $vm.colliders)
                        .frame(height: 220)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

                    Button(action: { Task { await vm.detectRooms() } }) {
                        Group {
                            if vm.isLoading {
                                HStack { ProgressView().scaleEffect(0.7); Text("Detecting rooms…") }
                            } else {
                                Label("Detect Rooms via API", systemImage: "rectangle.dashed.badge.record")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isLoading || vm.selectedModel == nil)
                }

                // Collider list
                if !vm.colliders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Colliders (\(vm.colliders.filter { $0.isSelected }.count) selected)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        ForEach($vm.colliders) { $collider in
                            ColliderRow(collider: $collider)
                        }
                    }
                }

                // Error
                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06))
                        .cornerRadius(8)
                }

                // Saved floor plans
                if !vm.savedFloorPlans.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Saved Floor Plans", systemImage: "folder")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        ForEach(vm.savedFloorPlans) { plan in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.name).font(.system(size: 12, weight: .medium))
                                    Text(plan.date, style: .date).font(.system(size: 10)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: { vm.deleteSaved(id: plan.id) }) {
                                    Image(systemName: "trash").foregroundColor(.red).font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showSaveSheet) {
            VStack(spacing: 16) {
                Text("Save Floor Plan").font(.headline)
                TextField("Name", text: $saveName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { showSaveSheet = false }
                    Button("Save") {
                        vm.saveSelected(name: saveName.isEmpty ? "Floor Plan" : saveName)
                        saveName = ""
                        showSaveSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .frame(width: 280)
        }
        .onAppear { vm.selectedModel = vm.availableModels.first }
    }
}

// MARK: - Floor plan canvas with interactive colliders

struct FloorPlanCanvas: View {
    let image: NSImage
    @Binding var colliders: [RoomCollider]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach($colliders) { $collider in
                    if collider.isSelected {
                        ResizableColliderView(collider: $collider, canvasSize: geo.size, imageSize: image.size)
                    }
                }
            }
        }
    }
}

struct ResizableColliderView: View {
    @Binding var collider: RoomCollider
    let canvasSize: CGSize
    let imageSize: CGSize

    private var scale: CGSize {
        let sw = canvasSize.width / imageSize.width
        let sh = canvasSize.height / imageSize.height
        let s = min(sw, sh)
        return CGSize(width: s, height: s)
    }

    private var scaledRect: CGRect {
        CGRect(
            x: collider.rect.minX * scale.width,
            y: collider.rect.minY * scale.height,
            width: collider.rect.width * scale.width,
            height: collider.rect.height * scale.height
        )
    }

    var body: some View {
        let sr = scaledRect
        ZStack {
            Rectangle()
                .fill(Color(collider.color))
                .frame(width: sr.width, height: sr.height)
                .overlay(
                    Rectangle().stroke(Color(collider.color.withAlphaComponent(1)), lineWidth: 1.5)
                )
                .overlay(
                    Text(collider.label)
                        .font(.system(size: min(10, sr.width / 5)))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                        .padding(3),
                    alignment: .topLeading
                )
                .offset(x: sr.minX + sr.width / 2 - canvasSize.width / 2,
                        y: sr.minY + sr.height / 2 - canvasSize.height / 2)

            // Corner handles
            ForEach(Corner.allCases, id: \.self) { corner in
                CornerHandle(corner: corner)
                    .offset(x: sr.minX + corner.x(sr) - canvasSize.width / 2,
                            y: sr.minY + corner.y(sr) - canvasSize.height / 2)
                    .gesture(DragGesture()
                        .onChanged { drag in
                            var r = collider.rect
                            let dx = drag.translation.width / scale.width
                            let dy = drag.translation.height / scale.height
                            switch corner {
                            case .topLeft:
                                r.origin.x += dx; r.size.width -= dx
                                r.origin.y += dy; r.size.height -= dy
                            case .topRight:
                                r.size.width += dx
                                r.origin.y += dy; r.size.height -= dy
                            case .bottomLeft:
                                r.origin.x += dx; r.size.width -= dx
                                r.size.height += dy
                            case .bottomRight:
                                r.size.width += dx; r.size.height += dy
                            }
                            if r.width > 10 && r.height > 10 { collider.rect = r }
                        }
                    )
            }
        }
    }
}

enum Corner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
    func x(_ r: CGRect) -> CGFloat {
        switch self { case .topLeft, .bottomLeft: return 0; case .topRight, .bottomRight: return r.width }
    }
    func y(_ r: CGRect) -> CGFloat {
        switch self { case .topLeft, .topRight: return 0; case .bottomLeft, .bottomRight: return r.height }
    }
}

struct CornerHandle: View {
    let corner: Corner
    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: 10, height: 10)
    }
}

struct ColliderRow: View {
    @Binding var collider: RoomCollider

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $collider.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
            Circle()
                .fill(Color(collider.color.withAlphaComponent(1)))
                .frame(width: 12, height: 12)
            Text(collider.label)
                .font(.system(size: 12))
            Spacer()
            Text("\(Int(collider.rect.width))×\(Int(collider.rect.height))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
