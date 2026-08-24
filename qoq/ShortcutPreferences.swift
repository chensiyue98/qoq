import AppKit
import Carbon
import Combine
import SwiftUI

struct GlobalShortcut: Codable, Hashable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let selectionDefault = GlobalShortcut(keyCode: UInt32(kVK_ANSI_Q), modifiers: UInt32(controlKey))
    static let captureDefault = GlobalShortcut(keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(controlKey))
    static let extractTextDefault = GlobalShortcut(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(controlKey))

    var displayName: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += Self.keyNames[keyCode] ?? "Key \(keyCode)"
        return result
    }

    var keyEquivalent: KeyEquivalent {
        switch keyCode {
        case UInt32(kVK_Space): .space
        case UInt32(kVK_Return): .return
        case UInt32(kVK_Tab): .tab
        case UInt32(kVK_LeftArrow): .leftArrow
        case UInt32(kVK_RightArrow): .rightArrow
        case UInt32(kVK_UpArrow): .upArrow
        case UInt32(kVK_DownArrow): .downArrow
        default:
            KeyEquivalent(Character((Self.keyNames[keyCode] ?? "?").lowercased()))
        }
    }

    var eventModifiers: SwiftUI.EventModifiers {
        var result: SwiftUI.EventModifiers = []
        if modifiers & UInt32(controlKey) != 0 { result.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { result.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { result.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { result.insert(.command) }
        return result
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        guard carbonFlags != 0, event.keyCode != UInt16(kVK_Escape) else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: carbonFlags)
    }

    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9", UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥", UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓"
    ]
}

@MainActor
final class ShortcutPreferences: ObservableObject {
    @Published private(set) var selection: GlobalShortcut
    @Published private(set) var capture: GlobalShortcut
    @Published private(set) var extractText: GlobalShortcut
    @Published var errorMessage: String?
    var onChange: ((GlobalShortcut, GlobalShortcut, GlobalShortcut) -> Bool)?

    init() {
        selection = Self.load("selectionShortcut") ?? .selectionDefault
        capture = Self.load("captureShortcut") ?? .captureDefault
        extractText = Self.load("extractTextShortcut") ?? .extractTextDefault
    }

    func setSelection(_ shortcut: GlobalShortcut) { apply(selection: shortcut, capture: capture, extractText: extractText) }
    func setCapture(_ shortcut: GlobalShortcut) { apply(selection: selection, capture: shortcut, extractText: extractText) }
    func setExtractText(_ shortcut: GlobalShortcut) { apply(selection: selection, capture: capture, extractText: shortcut) }
    func reset() { apply(selection: .selectionDefault, capture: .captureDefault, extractText: .extractTextDefault) }

    private func apply(selection newSelection: GlobalShortcut, capture newCapture: GlobalShortcut, extractText newExtractText: GlobalShortcut) {
        guard Set([newSelection, newCapture, newExtractText]).count == 3 else {
            errorMessage = L("三个功能不能使用相同的快捷键。")
            NSSound.beep()
            return
        }
        guard onChange?(newSelection, newCapture, newExtractText) ?? true else {
            errorMessage = L("快捷键已被系统或其他应用占用，请换一个组合。")
            NSSound.beep()
            return
        }
        selection = newSelection
        capture = newCapture
        extractText = newExtractText
        errorMessage = nil
        Self.save(newSelection, key: "selectionShortcut")
        Self.save(newCapture, key: "captureShortcut")
        Self.save(newExtractText, key: "extractTextShortcut")
    }

    private static func load(_ key: String) -> GlobalShortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GlobalShortcut.self, from: data)
    }

    private static func save(_ shortcut: GlobalShortcut, key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(shortcut), forKey: key)
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: GlobalShortcut
    let onChange: (GlobalShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderView {
        ShortcutRecorderView(shortcut: shortcut, onChange: onChange)
    }

    func updateNSView(_ view: ShortcutRecorderView, context: Context) {
        view.shortcut = shortcut
        view.onChange = onChange
        view.needsDisplay = true
    }
}

final class ShortcutRecorderView: NSView {
    var shortcut: GlobalShortcut
    var onChange: (GlobalShortcut) -> Void
    private var isRecording = false

    init(shortcut: GlobalShortcut, onChange: @escaping (GlobalShortcut) -> Void) {
        self.shortcut = shortcut
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 104, height: 26))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 104, height: 26) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            window?.makeFirstResponder(nil)
            return
        }
        guard let value = GlobalShortcut(event: event) else {
            NSSound.beep()
            return
        }
        onChange(value)
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        shape.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        shape.lineWidth = isRecording ? 1.5 : 1
        shape.stroke()
        let text = isRecording ? L("请按快捷键…") : shortcut.displayName
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}
