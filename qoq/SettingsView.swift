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
}
