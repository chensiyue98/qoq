import AppKit
import Combine
import SwiftUI
import Translation

@MainActor
final class TranslationPanelState: ObservableObject {
    @Published var isPinned = false
}

@MainActor
final class TranslationPanelController: NSWindowController, NSWindowDelegate {
    private let model: TranslationModel
    private let state = TranslationPanelState()

    init(model: TranslationModel) {
        self.model = model
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 420, height: 310)
        panel.contentView = NSHostingView(rootView: TranslationPanelView(model: model, state: state))
        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowDidResignKey(_ notification: Notification) {
        guard !state.isPinned else { return }
        close()
    }

    func show(text: String, source: TranslationSource) {
        showWindowNearPointer()
        model.requestTranslation(text, source: source)
    }

    func showLoading(source: TranslationSource) {
        showWindowNearPointer()
        model.source = source
        model.sourceText = "正在识别屏幕文字…"
        model.translatedText = ""
        model.errorMessage = nil
        model.isWorking = true
    }

    func show(error: String) {
        showWindowNearPointer()
        model.showError(error)
    }

    private func showWindowNearPointer() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let origin = NSPoint(
                x: min(max(mouse.x - window.frame.width / 2, visible.minX), visible.maxX - window.frame.width),
                y: min(max(mouse.y - window.frame.height - 20, visible.minY), visible.maxY - window.frame.height)
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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.65)
            content
            Divider().opacity(0.65)
            footer
        }
        .background(.regularMaterial)
        .translationTask(model.configuration) { session in
            await model.perform(using: session)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label(model.source.label, systemImage: model.source == .screen ? "viewfinder" : "text.cursor")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                state.isPinned.toggle()
            } label: {
                Image(systemName: state.isPinned ? "pin.fill" : "pin")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(state.isPinned ? Color.accentColor : Color.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help(state.isPinned ? "取消固定窗口" : "固定窗口置顶")
            .accessibilityLabel(state.isPinned ? "取消固定窗口" : "固定窗口置顶")
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
        }
        .font(.system(size: 13))
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            editableSourceSection
            Divider()
            if let error = model.errorMessage {
                ContentUnavailableView("无法完成翻译", systemImage: "exclamationmark.triangle", description: Text(error))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.needsSourceSelection {
                sourceLanguagePrompt
            } else if model.isWorking {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text(model.source == .screen && model.sourceText.hasPrefix("正在识别") ? "识别中" : "翻译中")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                textSection(title: model.targetName, text: model.translatedText, muted: false)
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
        }
        .frame(maxHeight: .infinity, alignment: .top)
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
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var footer: some View {
        HStack {
            Text("全局快捷键可在设置中自定义")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.tertiary)
            Spacer()
            Button { model.translateEditedText() } label: {
                Label("重新翻译", systemImage: "arrow.clockwise")
            }
            .disabled(model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
            .keyboardShortcut(.return, modifiers: [.command])
            Button { model.copyTranslation() } label: {
                Label("复制译文", systemImage: "doc.on.doc")
            }
            .disabled(model.translatedText.isEmpty)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}
