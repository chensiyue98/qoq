import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = TranslationModel()
    let shortcuts = ShortcutPreferences()
    private var hotKeys: HotKeyManager?
    private var panel: TranslationPanelController?
    private var selector: ScreenSelectionController?
    private var permissionGuide: PermissionGuideController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = TranslationPanelController(model: model)
        hotKeys = HotKeyManager(
            selection: shortcuts.selection,
            capture: shortcuts.capture,
            translateSelection: { [weak self] in self?.translateSelection() },
            captureScreen: { [weak self] in self?.captureScreen() }
        )
        shortcuts.onChange = { [weak self] selection, capture in
            self?.hotKeys?.update(selection: selection, capture: capture) ?? false
        }
        if !UserDefaults.standard.bool(forKey: "didShowPermissionGuide") {
            DispatchQueue.main.async { [weak self] in self?.showPermissionGuide() }
        }
    }

    func showPermissionGuide() {
        if permissionGuide == nil {
            permissionGuide = PermissionGuideController { [weak self] in
                UserDefaults.standard.set(true, forKey: "didShowPermissionGuide")
                self?.permissionGuide = nil
            }
        }
        permissionGuide?.showWindow(nil)
        permissionGuide?.window?.center()
        permissionGuide?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func translateSelection() {
        do {
            let text = try SelectedTextReader.read()
            panel?.show(text: text, source: .selection)
        } catch {
            panel?.show(error: error.localizedDescription)
        }
    }

    func captureScreen() {
        guard ScreenOCRService.ensureScreenCapturePermission() else {
            panel?.show(error: "需要“屏幕与系统音频录制”权限。请在系统设置的“隐私与安全性”中允许 QoQ。")
            return
        }
        selector = ScreenSelectionController { [weak self] result in
            guard let self else { return }
            self.selector = nil
            switch result {
            case .success(let capture):
                self.panel?.showLoading(source: .screen)
                Task {
                    do {
                        let text = try await ScreenOCRService.recognize(capture.image)
                        self.panel?.show(text: text, source: .screen)
                    } catch {
                        self.panel?.show(error: error.localizedDescription)
                    }
                }
            case .failure(let error):
                if !(error is CancellationError) { self.panel?.show(error: error.localizedDescription) }
            }
        }
        selector?.begin()
    }
}
