import SwiftUI

@main
struct QoQApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("QoQ", systemImage: "character.bubble") {
            Button("翻译所选文字") {
                appDelegate.translateSelection()
            }
            Button("框选屏幕翻译") {
                appDelegate.captureScreen()
            }

            Divider()

            Button("权限引导…") {
                appDelegate.showPermissionGuide()
            }
            Button("设置…") {
                appDelegate.showSettings()
            }

            Divider()

            Button("退出 QoQ") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
