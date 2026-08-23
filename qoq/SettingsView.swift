import AppKit
import Combine
import SwiftUI
import Translation

@MainActor
final class OfflineLanguageManager: ObservableObject {
    @available(macOS 26.4, *)
    static let strategy: TranslationSession.Strategy = .lowLatency
    enum Status: Equatable {
        case checking
        case installed
        case available
        case unsupported
        case notNeeded
        case downloading
        case failed(String)

        var title: String {
            switch self {
            case .checking: "正在检查"
            case .installed: "已下载"
            case .available: "可下载"
            case .unsupported: "不支持"
            case .notNeeded: "无需下载"
            case .downloading: "正在下载"
            case .failed: "下载失败"
            }
        }

        var symbol: String {
            switch self {
            case .checking, .downloading: "arrow.trianglehead.2.clockwise.rotate.90"
            case .installed: "checkmark.circle.fill"
            case .available: "arrow.down.circle"
            case .unsupported, .failed: "exclamationmark.triangle.fill"
            case .notNeeded: "checkmark.circle"
            }
        }

        var canDownload: Bool {
            switch self {
            case .available, .failed: true
            default: false
            }
        }
    }

    @Published private(set) var status: Status = .checking
    @Published var sourceLanguage = "en"
    @Published var targetLanguage = "zh-Hans"
    @Published var downloadConfiguration: TranslationSession.Configuration?
    private let availability: LanguageAvailability = {
        if #available(macOS 26.4, *) {
            return LanguageAvailability(preferredStrategy: strategy)
        }
        return LanguageAvailability()
    }()

    func refresh() async {
        let source = sourceLanguage
        let target = targetLanguage
        if source == target || ChineseVariantConverter.convert("", sourceLanguage: source, targetLanguage: target) != nil {
            status = .notNeeded
            return
        }
        status = .checking
        let result = await availability.status(
            from: Locale.Language(identifier: source),
            to: Locale.Language(identifier: target)
        )
        guard !Task.isCancelled else { return }
        switch result {
        case .installed: status = .installed
        case .supported: status = .available
        case .unsupported: status = .unsupported
        @unknown default: status = .unsupported
        }
    }

    func beginDownload() {
        status = .downloading
        if #available(macOS 26.4, *) {
            downloadConfiguration = .init(
                source: Locale.Language(identifier: sourceLanguage),
                target: Locale.Language(identifier: targetLanguage),
                preferredStrategy: Self.strategy
            )
        } else {
            downloadConfiguration = .init(
                source: Locale.Language(identifier: sourceLanguage),
                target: Locale.Language(identifier: targetLanguage)
            )
        }
    }

    func fail(_ error: Error) {
        downloadConfiguration = nil
        status = .failed(error.localizedDescription)
    }
}

struct SettingsView: View {
    @ObservedObject var model: TranslationModel
    @ObservedObject var shortcuts: ShortcutPreferences
    @StateObject private var offlineLanguages = OfflineLanguageManager()
    @AppStorage("translationWindowPosition") private var translationWindowPosition = TranslationWindowPosition.screenCenter.rawValue
    @AppStorage("translationAppearanceMode") private var translationAppearanceMode = TranslationAppearanceMode.automatic.rawValue
    @AppStorage("translationBackgroundOpacity") private var translationBackgroundOpacity = 0.82
    @AppStorage("translationBackgroundBlur") private var translationBackgroundBlur = TranslationBackgroundBlur.standard.rawValue

    var body: some View {
        Form {
            Section("翻译") {
                Picker("默认目标语言", selection: $model.targetLanguage) {
                    ForEach(LanguageChoice.supported) { language in
                        Text(language.title).tag(language.id)
                    }
                }
                Picker("同语种候选语言", selection: $model.fallbackLanguage) {
                    ForEach(LanguageChoice.supported) { language in
                        Text(language.title).tag(language.id)
                    }
                }
                Text("检测语言与默认目标语言一致时，改为翻译成候选语言。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("词典") {
                Picker("备用词典", selection: $model.dictionaryFallbackMode) {
                    ForEach(DictionaryFallbackMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                Text("无法可靠识别短文本的语言时，使用系统词典查找释义。具体词典及优先级由“词典”App 管理。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("打开“词典”…") {
                        openDictionaryApp()
                    }
                }
            }
            Section("窗口") {
                Picker("弹出位置", selection: $translationWindowPosition) {
                    ForEach(TranslationWindowPosition.allCases) { position in
                        Text(position.title).tag(position.rawValue)
                    }
                }
                Text("窗口显示在鼠标当前所在的屏幕上。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("外观") {
                Picker("外观", selection: $translationAppearanceMode) {
                    ForEach(TranslationAppearanceMode.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
                Picker("背景模糊", selection: $translationBackgroundBlur) {
                    ForEach(TranslationBackgroundBlur.allCases) { blur in
                        Text(blur.title).tag(blur.rawValue)
                    }
                }
                LabeledContent("背景不透明度") {
                    HStack(spacing: 10) {
                        Slider(value: $translationBackgroundOpacity, in: 0.35...1, step: 0.05)
                            .frame(width: 180)
                        Text("\(Int((translationBackgroundOpacity * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                Text("外观设置会立即应用到翻译窗口。透明度只影响背景，不影响文字。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("离线语言") {
                HStack(spacing: 8) {
                    Picker("原文", selection: $offlineLanguages.sourceLanguage) {
                        ForEach(LanguageChoice.supported) { language in
                            Text(language.title).tag(language.id)
                        }
                    }
                    .labelsHidden()
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.tertiary)
                    Picker("译文", selection: $offlineLanguages.targetLanguage) {
                        ForEach(LanguageChoice.supported) { language in
                            Text(language.title).tag(language.id)
                        }
                    }
                    .labelsHidden()
                    Spacer()
                    Label(offlineLanguages.status.title, systemImage: offlineLanguages.status.symbol)
                        .font(.callout)
                        .foregroundStyle(statusColor)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("下载") {
                        offlineLanguages.beginDownload()
                    }
                    .disabled(!offlineLanguages.status.canDownload)
                    Button("在系统设置中管理…") {
                        guard let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") else { return }
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Section("快捷键") {
                LabeledContent("翻译所选文字") {
                    ShortcutRecorder(shortcut: shortcuts.selection, onChange: shortcuts.setSelection)
                }
                LabeledContent("框选屏幕翻译") {
                    ShortcutRecorder(shortcut: shortcuts.capture, onChange: shortcuts.setCapture)
                }
                HStack {
                    if let error = shortcuts.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("点击快捷键框，然后按下新的组合键。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("恢复默认") { shortcuts.reset() }
                        .controlSize(.small)
                }
            }
            Section("权限") {
                Text("划词翻译需要辅助功能权限；屏幕识别需要屏幕录制权限。系统会在首次使用时请求。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("支持") {
                Link(destination: URL(string: "https://buymeacoffee.com/chensiyue98")!) {
                    Label("请我喝杯咖啡", systemImage: "cup.and.saucer")
                }
                Text("如果 QoQ 对你有帮助，可以支持它继续改进。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("QoQ 设置")
        .task(id: "\(offlineLanguages.sourceLanguage)-\(offlineLanguages.targetLanguage)") {
            offlineLanguages.downloadConfiguration = nil
            await offlineLanguages.refresh()
        }
        .translationTask(offlineLanguages.downloadConfiguration) { session in
            do {
                try await session.prepareTranslation()
                offlineLanguages.downloadConfiguration = nil
                await offlineLanguages.refresh()
            } catch {
                offlineLanguages.fail(error)
            }
        }
    }

    private var statusColor: Color {
        switch offlineLanguages.status {
        case .installed, .notNeeded: .green
        case .failed, .unsupported: .orange
        default: .secondary
        }
    }

    private var statusDescription: String {
        switch offlineLanguages.status {
        case .checking: "正在读取系统语言资源状态。"
        case .installed: "这个语言对已下载，可离线使用。"
        case .available: "语言资源尚未下载；macOS 会显示下载确认窗口。"
        case .unsupported: "系统 Translation framework 不支持这个语言对。"
        case .notNeeded:
            offlineLanguages.sourceLanguage == offlineLanguages.targetLanguage
                ? "原文和译文语言相同。"
                : "繁简转换使用系统内置资源，无需下载。"
        case .downloading: "正在等待 macOS 下载并准备语言资源。"
        case .failed(let message): message
        }
    }

    private func openDictionaryApp() {
        let candidates = [
            "/System/Applications/Dictionary.app",
            "/Applications/Dictionary.app"
        ]
        guard let path = candidates.first(where: FileManager.default.fileExists(atPath:)) else { return }
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: path),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
