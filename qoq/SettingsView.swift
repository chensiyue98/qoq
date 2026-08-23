import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: TranslationModel
    @ObservedObject var shortcuts: ShortcutPreferences

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
    }
}
