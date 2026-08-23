import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import SwiftUI

@MainActor
final class PermissionGuideController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用 QoQ"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 460, height: 340)
        window.contentMaxSize = NSSize(width: 460, height: 340)
        window.contentView = NSHostingView(
            rootView: PermissionGuideView(status: PermissionStatusModel(), close: { window.close() })
                .frame(width: 460, height: 340)
        )
        window.setContentSize(NSSize(width: 460, height: 340))
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowWillClose(_ notification: Notification) { onClose() }
}

private struct PermissionGuideView: View {
    @ObservedObject var status: PermissionStatusModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("先授予两项权限")
                        .font(.system(size: 19, weight: .semibold))
                    Text("QoQ 只在你按下快捷键时读取选区或截取框选区域。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)

            permissionRow(
                icon: "text.cursor",
                title: "辅助功能",
                explanation: "读取当前应用中已经选中的文字，用于快捷键划词翻译。",
                granted: status.accessibilityGranted,
                action: requestAccessibility
            )

            Divider().padding(.leading, 46)

            permissionRow(
                icon: "rectangle.dashed",
                title: "屏幕录制",
                explanation: "仅截取你拖动框选的区域，使用系统 Vision 在本机识别文字。",
                granted: status.screenCaptureGranted,
                action: requestScreenCapture
            )

            Spacer(minLength: 12)

            HStack {
                Text("之后可从菜单栏的“权限引导”再次打开。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("完成") { close() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .background(.regularMaterial)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            status.refresh()
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        explanation: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(granted ? Color.green : Color.accentColor)
                .frame(width: 30, height: 30)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(title).fontWeight(.medium)
                    if granted {
                        Label("已允许", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(granted ? "已完成" : "允许") { action() }
                .disabled(granted)
                .controlSize(.regular)
        }
        .padding(.vertical, 10)
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        openPrivacyPane("Privacy_Accessibility")
        status.refresh()
    }

    private func requestScreenCapture() {
        CGRequestScreenCaptureAccess()
        if !CGPreflightScreenCaptureAccess() { openPrivacyPane("Privacy_ScreenCapture") }
        status.refresh()
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

}

@MainActor
private final class PermissionStatusModel: ObservableObject {
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var screenCaptureGranted = CGPreflightScreenCaptureAccess()

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        screenCaptureGranted = CGPreflightScreenCaptureAccess()
    }
}
