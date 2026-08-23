import AppKit
import Combine
import ServiceManagement
import SwiftUI
import Translation

@MainActor
final class UpdateChecker: ObservableObject {
    enum Status {
        case idle
        case checking
        case upToDate(String)
        case updateAvailable(version: String, url: URL)
        case failed(String)
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private enum CheckError: LocalizedError {
        case invalidResponse
        case noPublishedRelease

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "GitHub 返回了无法识别的响应。"
            case .noPublishedRelease: "项目尚未发布可供下载的版本。"
            }
        }
    }

    @Published private(set) var status: Status = .idle

    func check() async {
        if case .checking = status { return }
        status = .checking
        await performCheck()
    }

    private func performCheck() async {
        do {
            let endpoint = URL(string: "https://api.github.com/repos/chensiyuechen/qoq/releases/latest")!
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("QoQ Update Checker", forHTTPHeaderField: "User-Agent")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw CheckError.invalidResponse }
            if response.statusCode == 404 { throw CheckError.noPublishedRelease }
            guard (200..<300).contains(response.statusCode) else { throw CheckError.invalidResponse }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            if Self.isNewer(release.tagName, than: current) {
                status = .updateAvailable(version: release.tagName, url: release.htmlURL)
            } else {
                status = .upToDate(current)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) == .orderedDescending
    }

    nonisolated static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionComponents(lhs)
        let right = versionComponents(rhs)
        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue != rightValue { return leftValue > rightValue ? .orderedDescending : .orderedAscending }
        }
        return .orderedSame
    }

    nonisolated private static func versionComponents(_ version: String) -> [Int] {
        let core = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: "-", maxSplits: 1)
            .first ?? ""
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }
}

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
        case .requiresApproval:
            isEnabled = true
            requiresApproval = true
        case .notRegistered, .notFound:
            isEnabled = false
            requiresApproval = false
        @unknown default:
            isEnabled = false
            requiresApproval = false
        }
    }
}

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
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @StateObject private var updateChecker = UpdateChecker()
    @AppStorage("translationWindowPosition") private var translationWindowPosition = TranslationWindowPosition.screenCenter.rawValue
    @AppStorage("translationAppearanceMode") private var translationAppearanceMode = TranslationAppearanceMode.automatic.rawValue
    @AppStorage("translationBackgroundOpacity") private var translationBackgroundOpacity = 0.82
    @AppStorage("translationBackgroundBlur") private var translationBackgroundBlur = TranslationBackgroundBlur.standard.rawValue
    @AppStorage(TranslationBehaviorKey.showInputField) private var showInputField = true
    @AppStorage(TranslationBehaviorKey.showLanguageBar) private var showLanguageBar = true
    @AppStorage(TranslationBehaviorKey.replaceLineBreaks) private var replaceLineBreaks = false
    @AppStorage(TranslationBehaviorKey.removeCommentMarkers) private var removeCommentMarkers = false
    @AppStorage(TranslationBehaviorKey.removeDashPrefixes) private var removeDashPrefixes = false
    @AppStorage(TranslationBehaviorKey.copyOCRResult) private var copyOCRResult = false
    @AppStorage(TranslationBehaviorKey.copyFirstTranslation) private var copyFirstTranslation = false
    @AppStorage(TranslationBehaviorKey.speakSourceText) private var speakSourceText = false

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("通用", systemImage: "gearshape") }
            translationSettings
                .tabItem { Label("翻译", systemImage: "character.bubble") }
            offlineLanguageSettings
                .tabItem { Label("离线语言", systemImage: "arrow.down.circle") }
            shortcutSettings
                .tabItem { Label("快捷键", systemImage: "keyboard") }
            aboutSettings
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .padding(.top, 8)
        .onAppear {
            launchAtLogin.refresh()
        }
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

    private var generalSettings: some View {
        Form {
            Section("启动") {
                Toggle(
                    "开机启动",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: launchAtLogin.setEnabled
                    )
                )
                Text(launchAtLoginDescription)
                    .font(.caption)
                    .foregroundStyle(launchAtLogin.errorMessage == nil ? Color.secondary : Color.red)
            }
            Section("窗口") {
                Toggle("显示输入框", isOn: $showInputField)
                Toggle("显示语言切换栏", isOn: $showLanguageBar)
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
        }
        .formStyle(.grouped)
    }

    private var translationSettings: some View {
        Form {
            Section("语言") {
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
            Section("原文处理") {
                Toggle("将原文换行替换为空格", isOn: $replaceLineBreaks)
                Toggle("去掉原文的代码注释符号", isOn: $removeCommentMarkers)
                Toggle("去掉原文行首的“- ”", isOn: $removeDashPrefixes)
            }
            Section("自动操作") {
                Toggle("自动复制识别文字", isOn: $copyOCRResult)
                Toggle("自动复制翻译", isOn: $copyFirstTranslation)
                Toggle("自动朗读翻译原文", isOn: $speakSourceText)
                Text("自动复制会覆盖剪贴板中当前的文本内容。")
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
                    Button("打开“词典”…") { openDictionaryApp() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var offlineLanguageSettings: some View {
        Form {
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
        }
        .formStyle(.grouped)
    }

    private var shortcutSettings: some View {
        Form {
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
    }

    private var aboutSettings: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "character.bubble.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.accentColor)
                    Text("QoQ")
                        .font(.title2.weight(.semibold))
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section("项目") {
                Link(destination: URL(string: "https://github.com/chensiyue98/qoq")!) {
                    Label("在 GitHub 上查看源代码", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            Section("更新") {
                HStack(spacing: 12) {
                    updateStatusView
                    Spacer()
                    Button("检查更新") {
                        Task { await updateChecker.check() }
                    }
                    .disabled(isCheckingForUpdates)
                }
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
    }

    @ViewBuilder private var updateStatusView: some View {
        switch updateChecker.status {
        case .idle:
            Text("当前\(versionText)")
                .foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在检查…")
            }
            .foregroundStyle(.secondary)
        case .upToDate(let version):
            Label("已是最新版本（\(version)）", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .updateAvailable(let version, let url):
            Link(destination: url) {
                Label("发现新版本 \(version)", systemImage: "arrow.down.circle.fill")
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var isCheckingForUpdates: Bool {
        if case .checking = updateChecker.status { return true }
        return false
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        if version.isEmpty { return build.isEmpty ? "" : "构建版本 \(build)" }
        return build.isEmpty ? "版本 \(version)" : "版本 \(version)（\(build)）"
    }

    private var statusColor: Color {
        switch offlineLanguages.status {
        case .installed, .notNeeded: .green
        case .failed, .unsupported: .orange
        default: .secondary
        }
    }

    private var launchAtLoginDescription: String {
        if let error = launchAtLogin.errorMessage {
            return "无法更改开机启动：\(error)"
        }
        if launchAtLogin.requiresApproval {
            return "需要在“系统设置 → 通用 → 登录项”中允许 QoQ。"
        }
        return "登录 macOS 后自动启动 QoQ。"
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
