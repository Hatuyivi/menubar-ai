import AppKit
import CoreGraphics

// MARK: - Screen area selector overlay window

class ScreenSelectorWindow: NSWindow {
    var onCapture: ((NSImage?) -> Void)?
    var onCancel: (() -> Void)?

    private var overlayView: SelectorOverlayView!

    init() {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        overlayView = SelectorOverlayView(frame: screenFrame)
        overlayView.onCapture = { [weak self] rect in
            self?.handleCapture(rect)
        }
        overlayView.onCancel = { [weak self] in
            self?.close()
            self?.onCancel?()
        }
        contentView = overlayView
    }

    private func handleCapture(_ rect: NSRect) {
        // Hide overlay immediately so it doesn't appear in the screenshot
        overlayView.isHidden = true
        close()

        // Small delay to ensure window is fully gone from compositor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            let image = ScreenSelectorWindow.captureRect(rect)
            self?.onCapture?(image)
        }
    }

    static func captureRect(_ rect: NSRect) -> NSImage? {
        guard let screen = NSScreen.main else { return nil }
        guard rect.width > 4, rect.height > 4 else { return nil }

        // Convert AppKit coords (y from bottom) → CGImage coords (y from top)
        let screenHeight = screen.frame.height
        let cgRect = CGRect(
            x: rect.minX,
            y: screenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )

        guard let cgImage = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: rect.size)
    }
}

// MARK: - Overlay drawing view

class SelectorOverlayView: NSView {
    var onCapture: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint = .zero
    private var currentRect: NSRect = .zero
    private var isDragging = false

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Dim entire screen
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.fill(bounds)

        if isDragging && currentRect.width > 2 && currentRect.height > 2 {
            // Punch out the selected area (transparent)
            ctx.clear(currentRect)

            // White border around selection
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(1.5)
            ctx.stroke(currentRect.insetBy(dx: 0.75, dy: 0.75))

            // Dimension label above selection
            let label = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.5)
            ]
            let nsLabel = label as NSString
            let size = nsLabel.size(withAttributes: attrs)
            var origin = NSPoint(x: currentRect.minX, y: currentRect.maxY + 4)
            if origin.y + size.height > bounds.maxY {
                origin.y = max(0, currentRect.minY - size.height - 4)
            }
            nsLabel.draw(at: origin, withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        isDragging = true
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(
            x: min(startPoint.x, pt.x),
            y: min(startPoint.y, pt.y),
            width: abs(pt.x - startPoint.x),
            height: abs(pt.y - startPoint.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if currentRect.width > 8 && currentRect.height > 8 {
            onCapture?(currentRect)
        } else {
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } // Escape
    }
}

// MARK: - NSImage helpers

extension NSImage {
    func pngBase64() -> String? {
        pngData()?.base64EncodedString()
    }

    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
