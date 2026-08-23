import AppKit
import ApplicationServices
import Carbon

enum SelectedTextError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "需要“辅助功能”权限才能读取其他应用中所选的文字。请在系统设置的“隐私与安全性”中允许 QoQ。"
        case .unavailable:
            "没有读取到所选文字。请先在支持文本选择的应用中选中文字。"
        }
    }
}

enum SelectedTextReader {
    static func read() throws -> String {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { throw SelectedTextError.permissionDenied }

        if let text = readFromAccessibility() { return text }
        if let text = readByCopyingSelection() { return text }
        throw SelectedTextError.unavailable
    }

    private static func readFromAccessibility() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return nil }
        var selected: CFTypeRef?
        let element = focused as! AXUIElement
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    private static func readByCopyingSelection() -> String? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        let clearedChangeCount = pasteboard.changeCount

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else {
            snapshot.restore(to: pasteboard)
            return nil
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(application.processIdentifier)
        keyUp.postToPid(application.processIdentifier)

        // Safari/WebKit updates the pasteboard asynchronously after handling ⌘C.
        let copied = waitForCopiedText(
            clearedChangeCount: clearedChangeCount,
            changeCount: { pasteboard.changeCount },
            string: { pasteboard.string(forType: .string) }
        )
        snapshot.restore(to: pasteboard)
        return copied?.isEmpty == false ? copied : nil
    }

    static func waitForCopiedText(
        clearedChangeCount: Int,
        timeout: TimeInterval = 1.0,
        changeCount: () -> Int,
        string: () -> String?,
        pumpEvents: (Date) -> Void = { RunLoop.current.run(until: $0) }
    ) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if changeCount() != clearedChangeCount,
               let text = string()?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
            pumpEvents(Date().addingTimeInterval(0.01))
        }
        return nil
    }
}

private struct PasteboardSnapshot {
    private struct Item {
        let values: [(NSPasteboard.PasteboardType, Data)]
    }

    private let items: [Item]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Item(values: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { saved -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in saved.values { item.setData(data, forType: type) }
            return item
        }
        if !restoredItems.isEmpty { pasteboard.writeObjects(restoredItems) }
    }
}
