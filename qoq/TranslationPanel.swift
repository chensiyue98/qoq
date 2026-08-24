import AppKit
import Combine
import SwiftUI
import Translation

@MainActor
enum QoQSettingsOpener {
    static let requestNotification = Notification.Name("QoQOpenSettingsRequested")

    static func open() {
        NotificationCenter.default.post(name: requestNotification, object: nil)
    }
}

enum TranslationWindowPosition: String, CaseIterable, Identifiable {
    case screenCenter
    case nearPointer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenCenter: L("屏幕中央")
        case .nearPointer: L("鼠标附近")
        }
    }
}

enum TranslationAppearanceMode: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: L("跟随系统")
        case .light: L("浅色")
        case .dark: L("深色")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum TranslationBackgroundBlur: String, CaseIterable, Identifiable {
    case disabled
    case subtle
    case standard
    case strong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: L("关闭")
        case .subtle: L("轻微")
        case .standard: L("标准")
        case .strong: L("强")
        }
    }
}

enum TranslationBackgroundStyle {
    nonisolated static func opacity(for requestedOpacity: Double) -> Double {
        min(max(requestedOpacity, 0.35), 1)
    }

    static func configure(
        _ view: NSVisualEffectView,
        blur: TranslationBackgroundBlur,
        opacity: Double
    ) {
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = Self.opacity(for: opacity)
        view.isHidden = blur == .disabled
        switch blur {
        case .disabled, .subtle:
            view.material = .underWindowBackground
        case .standard:
            view.material = .sidebar
        case .strong:
            view.material = .hudWindow
        }
    }
}

enum TranslationWindowPositioner {
    nonisolated static func origin(
        for position: TranslationWindowPosition,
        visibleFrame: NSRect,
        windowSize: NSSize,
        pointer: NSPoint
    ) -> NSPoint {
        switch position {
        case .screenCenter:
            NSPoint(
                x: visibleFrame.midX - windowSize.width / 2,
                y: visibleFrame.midY - windowSize.height / 2
            )
        case .nearPointer:
            NSPoint(
                x: min(max(pointer.x - windowSize.width / 2, visibleFrame.minX), visibleFrame.maxX - windowSize.width),
                y: min(max(pointer.y - windowSize.height - 20, visibleFrame.minY), visibleFrame.maxY - windowSize.height)
            )
        }
    }
}

@MainActor
final class TranslationPanelContainerView: NSView {
    let effectView = NSVisualEffectView()
    private let tintView = NSView()
    private let hostingView: NSHostingView<TranslationPanelView>
    private var defaultsObserver: NSObjectProtocol?

    init(rootView: TranslationPanelView) {
        hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        tintView.wantsLayer = true

        for view in [effectView, tintView, hostingView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        applyAppearanceSettings()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applyAppearanceSettings()
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAppearanceSettings()
    }

    private func applyAppearanceSettings() {
        let defaults = UserDefaults.standard
        let blur = defaults.string(forKey: "translationBackgroundBlur")
            .flatMap(TranslationBackgroundBlur.init(rawValue:)) ?? .standard
        let storedOpacity = defaults.object(forKey: "translationBackgroundOpacity") as? Double
        let opacity = TranslationBackgroundStyle.opacity(for: storedOpacity ?? 0.82)
        TranslationBackgroundStyle.configure(effectView, blur: blur, opacity: opacity)

        tintView.alphaValue = blur == .disabled ? opacity : 0.12 * opacity
        tintView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let appearance = defaults.string(forKey: "translationAppearanceMode")
            .flatMap(TranslationAppearanceMode.init(rawValue:)) ?? .automatic
        switch appearance {
        case .automatic: window?.appearance = nil
        case .light: window?.appearance = NSAppearance(named: .aqua)
        case .dark: window?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class TranslationPanelState: ObservableObject {
    @Published var isPinned = false
}

private struct TranslationPinButton: View {
    @ObservedObject var state: TranslationPanelState

    var body: some View {
        Button {
            state.isPinned.toggle()
        } label: {
            Image(systemName: state.isPinned ? "pin.fill" : "pin")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(state.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(TranslationHoverButtonStyle(compact: true))
        .help(state.isPinned ? L("取消固定窗口") : L("固定窗口置顶"))
        .accessibilityLabel(state.isPinned ? L("取消固定窗口") : L("固定窗口置顶"))
    }
}

private struct TranslationTitlebarControls: View {
    @ObservedObject var model: TranslationModel
    @ObservedObject var state: TranslationPanelState
    @AppStorage(TranslationBehaviorKey.showInputField) private var showInputField = true
    @AppStorage(TranslationBehaviorKey.showLanguageBar) private var showLanguageBar = true
    @AppStorage(TranslationBehaviorKey.replaceLineBreaks) private var replaceLineBreaks = false
    @AppStorage(TranslationBehaviorKey.removeCommentMarkers) private var removeCommentMarkers = false
    @AppStorage(TranslationBehaviorKey.removeDashPrefixes) private var removeDashPrefixes = false
    @AppStorage(TranslationBehaviorKey.copyOCRResult) private var copyOCRResult = false
    @AppStorage(TranslationBehaviorKey.copyFirstTranslation) private var copyFirstTranslation = false
    @AppStorage(TranslationBehaviorKey.speakSourceText) private var speakSourceText = false
    @AppStorage(AppLanguage.defaultsKey) private var appLanguage = AppLanguage.system.rawValue

    var body: some View {
        HStack(spacing: 4) {
            TranslationPinButton(state: state)
            Menu {
                Toggle("显示输入框", isOn: $showInputField)
                Toggle("显示语言切换栏", isOn: $showLanguageBar)
                Divider()
                Toggle("将原文换行替换为空格", isOn: $replaceLineBreaks)
                Toggle("去掉原文的代码注释符号", isOn: $removeCommentMarkers)
                Toggle("去掉原文行首的“- ”", isOn: $removeDashPrefixes)
                Divider()
                Toggle("自动复制识别文字", isOn: $copyOCRResult)
                Toggle("自动复制翻译", isOn: $copyFirstTranslation)
                Toggle("自动朗读翻译原文", isOn: $speakSourceText)
                Divider()
                Button {
                    state.isPinned.toggle()
                } label: {
                    if state.isPinned {
                        Label("固定窗口置顶", systemImage: "checkmark")
                    } else {
                        Text("固定窗口置顶")
                    }
                }
                Divider()
                Button("前往设置") {
                    QoQSettingsOpener.open()
                }
            } label: {
                Image(systemName: "switch.2")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .translationHoverControl()
            .help("更多操作")
            .accessibilityLabel("更多操作")
        }
        .environment(\.locale, (AppLanguage(rawValue: appLanguage) ?? .system).locale)
    }
}

fileprivate struct TranslationHoverButtonStyle: ButtonStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, compact ? 0 : 9)
            .padding(.vertical, compact ? 0 : 5)
            .frame(minWidth: compact ? 28 : nil, minHeight: 28)
            .background(
                ZStack {
                    TranslationHoverBackground()
                    Color.primary.opacity(configuration.isPressed ? 0.13 : 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct TranslationHoverBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> TranslationHoverTrackingView {
        TranslationHoverTrackingView()
    }

    func updateNSView(_ view: TranslationHoverTrackingView, context: Context) {
        view.synchronizeHoverState()
    }
}

private struct TranslationHoverControlModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .frame(minHeight: 28)
            .background(
                TranslationHoverBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private extension View {
    func translationHoverControl() -> some View {
        modifier(TranslationHoverControlModifier())
    }
}

private final class TranslationHoverTrackingView: NSView {
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTrackingArea = area
        synchronizeHoverState()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        synchronizeHoverState()
    }

    override func layout() {
        super.layout()
        synchronizeHoverState()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyColor()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyColor()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColor()
    }

    func synchronizeHoverState() {
        guard let window else {
            isHovered = false
            applyColor()
            return
        }
        let pointer = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        isHovered = bounds.contains(pointer)
        applyColor()
    }

    private func applyColor() {
        layer?.backgroundColor = isHovered
            ? NSColor.labelColor.withAlphaComponent(0.09).cgColor
            : NSColor.clear.cgColor
    }
}

@MainActor
final class TranslationPanelController: NSWindowController, NSWindowDelegate {
    static let defaultSize = NSSize(width: 520, height: 480)
    static let minimumSize = NSSize(width: 420, height: 380)

    private let model: TranslationModel
    private let state = TranslationPanelState()

    init(model: TranslationModel) {
        self.model = model
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = Self.minimumSize
        panel.contentView = TranslationPanelContainerView(
            rootView: TranslationPanelView(model: model, state: state)
        )
        super.init(window: panel)
        let controlsAccessory = NSTitlebarAccessoryViewController()
        controlsAccessory.layoutAttribute = .right
        let controlsHostingView = NSHostingView(
            rootView: TranslationTitlebarControls(model: model, state: state)
                .padding(.trailing, 12)
                .fixedSize()
        )
        let measuredSize = controlsHostingView.fittingSize
        controlsHostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: ceil(measuredSize.width),
            height: max(28, ceil(measuredSize.height))
        )
        controlsAccessory.view = controlsHostingView
        panel.addTitlebarAccessoryViewController(controlsAccessory)
        panel.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowDidResignKey(_ notification: Notification) {
        guard !state.isPinned else { return }
        close()
    }

    func show(text: String, source: TranslationSource) {
        showTranslationWindow()
        model.requestTranslation(text, source: source)
    }

    func showLoading(source: TranslationSource) {
        showTranslationWindow()
        model.source = source
        model.sourceText = L("正在识别屏幕文字…")
        model.translatedText = ""
        model.errorMessage = nil
        model.isWorking = true
    }

    func show(error: String) {
        showTranslationWindow()
        model.showError(error)
    }

    private func showTranslationWindow() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let storedPosition = UserDefaults.standard.string(forKey: "translationWindowPosition")
            let position = storedPosition.flatMap(TranslationWindowPosition.init(rawValue:)) ?? .screenCenter
            let origin = TranslationWindowPositioner.origin(
                for: position,
                visibleFrame: visible,
                windowSize: window.frame.size,
                pointer: mouse
            )
            window.setFrameOrigin(origin)
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct TranslationPanelView: View {
    @ObservedObject var model: TranslationModel
    @ObservedObject var state: TranslationPanelState
    @AppStorage("translationAppearanceMode") private var appearanceMode = TranslationAppearanceMode.automatic.rawValue
    @AppStorage(AppLanguage.defaultsKey) private var appLanguage = AppLanguage.system.rawValue
    @AppStorage(TranslationBehaviorKey.showInputField) private var showInputField = true
    @AppStorage(TranslationBehaviorKey.showLanguageBar) private var showLanguageBar = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.65)
            content
            Divider().opacity(0.65)
            footer
        }
        .preferredColorScheme(resolvedAppearance.colorScheme)
        .environment(\.locale, (AppLanguage(rawValue: appLanguage) ?? .system).locale)
        .translationTask(model.configuration) { session in
            await model.perform(using: session)
        }
    }

    private var resolvedAppearance: TranslationAppearanceMode {
        TranslationAppearanceMode(rawValue: appearanceMode) ?? .automatic
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label(model.source.label, systemImage: model.source == .screen ? "viewfinder" : "text.cursor")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if showLanguageBar {
                Menu(model.sourceName) {
                    Button("重新自动检测") { model.retryAutomaticDetection() }
                    Divider()
                    ForEach(LanguageChoice.supported) { language in
                        Button(language.title) { model.chooseSourceLanguage(language.id) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(model.needsSourceSelection ? Color.accentColor : Color.secondary)
                .translationHoverControl()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                Menu(model.targetName) {
                    ForEach(LanguageChoice.supported) { language in
                        Button(language.title) {
                            model.targetLanguage = language.id
                            if !model.sourceText.isEmpty { model.retranslate() }
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .translationHoverControl()
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showInputField {
                editableSourceSection
                Divider()
            }
            if let error = model.errorMessage {
                ContentUnavailableView("无法完成翻译", systemImage: "exclamationmark.triangle", description: Text(error))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.needsSourceSelection {
                sourceLanguagePrompt
            } else if model.isWorking {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text(model.source == .screen && model.sourceText == L("正在识别屏幕文字…") ? L("识别中") : L("翻译中"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                if model.outputKind == .dictionaryDefinition {
                    dictionarySection
                } else {
                    textSection(title: model.outputTitle, text: model.translatedText, muted: false)
                }
            }
        }
        .padding(18)
    }

    private var editableSourceSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("原文", systemImage: "pencil")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            TextEditor(text: $model.sourceText)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, -5)
                .accessibilityLabel("原文")
            textActionBar(
                speechAction: model.speakSourceText,
                speechLabel: L("朗读原文"),
                copyAction: model.copySourceText,
                copyLabel: L("复制原文"),
                disabled: model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .frame(
            minHeight: model.outputKind == .dictionaryDefinition ? 64 : nil,
            maxHeight: model.outputKind == .dictionaryDefinition ? 110 : .infinity,
            alignment: .top
        )
    }

    private var sourceLanguagePrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.magnify")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("选择原文语言")
                    .fontWeight(.medium)
                Text("这段文字太短或包含多种语言，无法可靠地自动判断。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu("选择…") {
                ForEach(LanguageChoice.supported) { language in
                    Button(language.title) { model.chooseSourceLanguage(language.id) }
                }
            }
            .controlSize(.large)
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func textSection(title: String, text: String, muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(muted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            textActionBar(
                speechAction: model.speakTranslation,
                speechLabel: L("朗读译文"),
                copyAction: model.copyTranslation,
                copyLabel: L("复制译文"),
                disabled: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var dictionarySection: some View {
        let layout = DictionaryDefinitionParser.parse(model.translatedText, term: model.sourceText)
        return VStack(alignment: .leading, spacing: 8) {
            Text("词典释义")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let metadata = layout.metadata {
                        Text(metadata)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                    }
                    ForEach(layout.senses) { sense in
                        HStack(alignment: .top, spacing: 10) {
                            if let number = sense.number {
                                Text(number)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 22, height: 22)
                                    .background(Color.accentColor.opacity(0.1), in: Circle())
                            }
                            dictionarySense(sense.definition)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            textActionBar(
                speechAction: model.speakTranslation,
                speechLabel: L("朗读译文"),
                copyAction: model.copyTranslation,
                copyLabel: L("复制释义"),
                disabled: model.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func dictionarySense(_ text: String) -> some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return VStack(alignment: .leading, spacing: 7) {
            if let definition = lines.first {
                Text(definition)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            ForEach(Array(lines.dropFirst().enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(line.replacingOccurrences(of: #"^•\s*"#, with: "", options: .regularExpression))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copyIconButton(action: @escaping () -> Void, label: String, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(TranslationHoverButtonStyle(compact: true))
        .disabled(disabled)
        .help(label)
        .accessibilityLabel(label)
    }

    private func speechIconButton(action: @escaping () -> Void, label: String, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(TranslationHoverButtonStyle(compact: true))
        .disabled(disabled)
        .help(label)
        .accessibilityLabel(label)
    }

    private func textActionBar(
        speechAction: @escaping () -> Void,
        speechLabel: String,
        copyAction: @escaping () -> Void,
        copyLabel: String,
        disabled: Bool
    ) -> some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)
            speechIconButton(action: speechAction, label: speechLabel, disabled: disabled)
            copyIconButton(action: copyAction, label: copyLabel, disabled: disabled)
        }
        .frame(height: 28)
        .padding(.top, 3)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button { model.translateEditedText() } label: {
                Label("重新翻译", systemImage: "arrow.clockwise")
            }
            .buttonStyle(TranslationHoverButtonStyle(compact: false))
            .disabled(model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}
