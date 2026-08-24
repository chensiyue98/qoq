import SwiftUI

@main
struct QoQApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppLanguage.defaultsKey) private var appLanguage = AppLanguage.system.rawValue

    var body: some Scene {
        MenuBarExtra("QoQ", systemImage: "character.bubble") {
            QoQMenuCommands(appDelegate: appDelegate, shortcuts: appDelegate.shortcuts)
                .environment(\.locale, (AppLanguage(rawValue: appLanguage) ?? .system).locale)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct QoQMenuCommands: View {
    let appDelegate: AppDelegate
    @ObservedObject var shortcuts: ShortcutPreferences

    var body: some View {
        Group {
            Button("翻译所选文字") { appDelegate.translateSelection() }
                .keyboardShortcut(shortcuts.selection.keyEquivalent, modifiers: shortcuts.selection.eventModifiers)
            Button("框选屏幕翻译") { appDelegate.captureScreen() }
                .keyboardShortcut(shortcuts.capture.keyEquivalent, modifiers: shortcuts.capture.eventModifiers)
            Button("提取屏幕文字") { appDelegate.extractScreenText() }
                .keyboardShortcut(shortcuts.extractText.keyEquivalent, modifiers: shortcuts.extractText.eventModifiers)

            Divider()

            Button("权限引导…") {
                appDelegate.showPermissionGuide()
            }
            Button("设置…") {
                appDelegate.showSettings()
            }

            Divider()

            Button("退出 QoQ") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
