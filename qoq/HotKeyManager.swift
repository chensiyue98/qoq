import Carbon

@MainActor
final class HotKeyManager {
    private var selectionRef: EventHotKeyRef?
    private var captureRef: EventHotKeyRef?
    private var extractTextRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let translateSelection: () -> Void
    private let captureScreen: () -> Void
    private let extractScreenText: () -> Void

    private var currentSelection: GlobalShortcut
    private var currentCapture: GlobalShortcut
    private var currentExtractText: GlobalShortcut

    init(selection: GlobalShortcut, capture: GlobalShortcut, extractText: GlobalShortcut, translateSelection: @escaping () -> Void, captureScreen: @escaping () -> Void, extractScreenText: @escaping () -> Void) {
        self.translateSelection = translateSelection
        self.captureScreen = captureScreen
        self.extractScreenText = extractScreenText
        self.currentSelection = selection
        self.currentCapture = capture
        self.currentExtractText = extractText

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            Task { @MainActor in
                if hotKeyID.id == 1 { manager.translateSelection() }
                if hotKeyID.id == 2 { manager.captureScreen() }
                if hotKeyID.id == 3 { manager.extractScreenText() }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)

        _ = register(selection: selection, capture: capture, extractText: extractText)
    }

    func update(selection: GlobalShortcut, capture: GlobalShortcut, extractText: GlobalShortcut) -> Bool {
        let oldSelection = currentSelection
        let oldCapture = currentCapture
        let oldExtractText = currentExtractText
        unregisterHotKeys()
        if register(selection: selection, capture: capture, extractText: extractText) {
            currentSelection = selection
            currentCapture = capture
            currentExtractText = extractText
            return true
        }
        unregisterHotKeys()
        _ = register(selection: oldSelection, capture: oldCapture, extractText: oldExtractText)
        return false
    }

    private func register(selection: GlobalShortcut, capture: GlobalShortcut, extractText: GlobalShortcut) -> Bool {
        let signature = OSType(0x514F5121)
        let selectionStatus = RegisterEventHotKey(selection.keyCode, selection.modifiers, EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &selectionRef)
        guard selectionStatus == noErr else { return false }
        let captureStatus = RegisterEventHotKey(capture.keyCode, capture.modifiers, EventHotKeyID(signature: signature, id: 2), GetApplicationEventTarget(), 0, &captureRef)
        guard captureStatus == noErr else { return false }
        let extractStatus = RegisterEventHotKey(extractText.keyCode, extractText.modifiers, EventHotKeyID(signature: signature, id: 3), GetApplicationEventTarget(), 0, &extractTextRef)
        return extractStatus == noErr
    }

    private func unregisterHotKeys() {
        if let selectionRef { UnregisterEventHotKey(selectionRef); self.selectionRef = nil }
        if let captureRef { UnregisterEventHotKey(captureRef); self.captureRef = nil }
        if let extractTextRef { UnregisterEventHotKey(extractTextRef); self.extractTextRef = nil }
    }

    deinit {
        if let selectionRef { UnregisterEventHotKey(selectionRef) }
        if let captureRef { UnregisterEventHotKey(captureRef) }
        if let extractTextRef { UnregisterEventHotKey(extractTextRef) }
        if let handler { RemoveEventHandler(handler) }
    }
}
