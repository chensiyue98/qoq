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
            SettingsLink {
                Text("设置…")
            }

            Divider()

            Button("退出 QoQ") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: appDelegate.model, shortcuts: appDelegate.shortcuts)
                .frame(width: 460, height: 400)
        }
    }
}
