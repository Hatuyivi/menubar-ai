import AppKit
import CoreGraphics

// MARK: - Screen area selector overlay window

class ScreenSelectorWindow: NSWindow {
    private var startPoint: NSPoint = .zero
    private var selectionRect: NSRect = .zero
    private var overlayView: SelectorOverlayView!
    var onCapture: ((NSImage?) -> Void)?

    init() {
        let screenFrame = NSScreen.main?.frame ?? .zero
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

        overlayView = SelectorOverlayView(frame: screenFrame)
        overlayView.onCapture = { [weak self] rect in
            self?.captureArea(rect)
        }
        overlayView.onCancel = { [weak self] in
            self?.close()
            self?.onCapture?(nil)
        }
        contentView = overlayView
    }

    private func captureArea(_ rect: NSRect) {
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            let image = self?.captureScreen(rect: rect)
            self?.onCapture?(image)
        }
    }

    private func captureScreen(rect: NSRect) -> NSImage? {
        guard let screen = NSScreen.main else { return nil }
        // Convert from AppKit coords (origin bottom-left) to CGImage coords (origin top-left)
        let screenHeight = screen.frame.height
        let cgRect = CGRect(
            x: rect.minX,
            y: screenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        guard cgRect.width > 4, cgRect.height > 4 else { return nil }
        guard let cgImage = CGWindowListCreateImage(cgRect, .optionOnScreenOnly, kCGNullWindowID, [.boundsIgnoreFraming, .bestResolution]) else { return nil }
        let image = NSImage(cgImage: cgImage, size: rect.size)
        return image
    }
}

class SelectorOverlayView: NSView {
    var onCapture: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint = .zero
    private var currentRect: NSRect = .zero
    private var isDragging = false

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Dim background
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSBezierPath(rect: bounds).fill()

        if isDragging && currentRect.width > 2 && currentRect.height > 2 {
            // Clear selection area
            NSGraphicsContext.current?.cgContext.clear(currentRect)

            // Selection border
            let border = NSBezierPath(rect: currentRect.insetBy(dx: 1, dy: 1))
            NSColor.white.withAlphaComponent(0.9).setStroke()
            border.lineWidth = 1.5
            border.stroke()

            // Dimension label
            let label = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let labelSize = (label as NSString).size(withAttributes: attrs)
            var labelOrigin = NSPoint(x: currentRect.minX + 4, y: currentRect.maxY + 4)
            if labelOrigin.y + labelSize.height > bounds.maxY { labelOrigin.y = currentRect.minY - labelSize.height - 4 }
            (label as NSString).draw(at: labelOrigin, withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        isDragging = true
        currentRect = .zero
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        let x = min(startPoint.x, current.x)
        let y = min(startPoint.y, current.y)
        let w = abs(current.x - startPoint.x)
        let h = abs(current.y - startPoint.y)
        currentRect = NSRect(x: x, y: y, width: w, height: h)
        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if currentRect.width > 10 && currentRect.height > 10 {
            onCapture?(currentRect)
        } else {
            setNeedsDisplay(bounds)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } // Escape
    }
}

// MARK: - NSImage helpers

extension NSImage {
    func pngBase64() -> String? {
        guard let data = pngData() else { return nil }
        return data.base64EncodedString()
    }

    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
