import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "viewfinder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("MenuBar AI")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "OCR", icon: "number.square", index: 0, selected: $selectedTab)
                TabButton(title: "Floor Plan", icon: "rectangle.split.3x3", index: 1, selected: $selectedTab)
                TabButton(title: "Settings", icon: "gearshape", index: 2, selected: $selectedTab)
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            Group {
                switch selectedTab {
                case 0: Module1View()
                case 1: Module2View()
                case 2: SettingsView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let index: Int
    @Binding var selected: Int

    var isSelected: Bool { selected == index }

    var body: some View {
        Button(action: { selected = index }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.08)
                    : Color.clear
            )
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .accentColor : .clear),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}
