import AppKit

@MainActor
final class ScreenOperationGate {
    private(set) var isActive = false

    func acquire() -> Bool {
        guard !isActive else { return false }
        isActive = true
        return true
    }

    func release() {
        isActive = false
    }
}

final class SelectionOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class ScreenSelectionController {
    private var windows: [NSWindow] = []
    private let completion: (Result<ScreenCapture, Error>) -> Void
    private var finished = false

    init(completion: @escaping (Result<ScreenCapture, Error>) -> Void) {
        self.completion = completion
    }

    func begin() {
        let screens = NSScreen.screens
        Task {
            do {
                let frozenScreens = try await withThrowingTaskGroup(of: (CGDirectDisplayID, FrozenScreenCapture).self) { group in
                    for screen in screens {
                        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
                        let displayID = CGDirectDisplayID(number.uint32Value)
                        group.addTask { (displayID, try await ScreenOCRService.freeze(screen: screen)) }
                    }
                    var captures: [CGDirectDisplayID: FrozenScreenCapture] = [:]
                    for try await (displayID, capture) in group { captures[displayID] = capture }
                    return captures
                }
                presentOverlays(on: screens, frozenScreens: frozenScreens)
            } catch {
                finish(.failure(error))
            }
        }
    }

    private func presentOverlays(on screens: [NSScreen], frozenScreens: [CGDirectDisplayID: FrozenScreenCapture]) {
        guard !finished else { return }
        NSApp.activate(ignoringOtherApps: true)
        for screen in screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let frozenScreen = frozenScreens[CGDirectDisplayID(number.uint32Value)] else { continue }
            let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.frozenImage = frozenScreen.image
            view.onCancel = { [weak self] in self?.finish(.failure(CancellationError())) }
            view.onSelection = { [weak self] localRect in
                guard let self else { return }
                do { self.finish(.success(try frozenScreen.crop(to: localRect))) }
                catch { self.finish(.failure(error)) }
            }
            let window = SelectionOverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.contentView = view
            window.makeFirstResponder(view)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        windows.first?.makeKey()
        NSCursor.crosshair.push()
    }

    private func finish(_ result: Result<ScreenCapture, Error>) {
        guard !finished else { return }
        finished = true
        hideOverlays()
        completion(result)
    }

    private func hideOverlays() {
        guard !windows.isEmpty else { return }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        NSCursor.pop()
    }
}

private final class SelectionOverlayView: NSView {
    var frozenImage: CGImage?
    var onSelection: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?
    private var start: NSPoint?
    private var current: NSPoint?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        let rect = selectionRect
        if rect.width >= 8, rect.height >= 8 { onSelection?(rect) } else { onCancel?() }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }

    private var selectionRect: NSRect {
        guard let start, let current else { return .zero }
        return NSRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(start.x - current.x), height: abs(start.y - current.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        if let frozenImage {
            NSGraphicsContext.current?.cgContext.draw(frozenImage, in: bounds)
        }
        NSColor.black.withAlphaComponent(0.36).setFill()
        bounds.fill()
        let rect = selectionRect
        if !rect.isEmpty {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: rect).addClip()
            NSColor.clear.setFill()
            bounds.fill(using: .copy)
            NSGraphicsContext.restoreGraphicsState()
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            border.lineWidth = 2
            border.stroke()
            let label = "\(Int(rect.width)) × \(Int(rect.height))"
            label.draw(at: NSPoint(x: rect.minX + 7, y: max(rect.minY - 23, 7)), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white
            ])
        } else {
            let message = L("拖动以选择文字区域  ·  Esc 取消")
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let size = message.size(withAttributes: attrs)
            message.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attrs)
        }
    }
}
