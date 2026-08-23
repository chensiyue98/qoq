import SwiftUI

@main
struct QoQApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppLanguage.defaultsKey) private var appLanguage = AppLanguage.system.rawValue

    var body: some Scene {
        MenuBarExtra("QoQ", systemImage: "character.bubble") {
            Group {
                Button("翻译所选文字") { appDelegate.translateSelection() }
                Button("框选屏幕翻译") { appDelegate.captureScreen() }
                Button("提取屏幕文字") { appDelegate.extractScreenText() }

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
            .environment(\.locale, (AppLanguage(rawValue: appLanguage) ?? .system).locale)
        }
        .menuBarExtraStyle(.menu)
    }
}
