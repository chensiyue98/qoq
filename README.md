# QoQ

[简体中文](README.zh-CN.md) | **English**

A native macOS menu bar translation app built entirely on system frameworks.

## Features

- `⌘ ⇧ D`: Read and translate text selected in the current app
- `⌘ ⇧ 2`: Select a screen region, recognize its text with Vision OCR, and translate it
- `⌘ ⇧ 1`: Select a screen region, extract its text with Vision OCR, and copy it to the clipboard without translating
- Record and save all three custom global shortcuts in Settings
- Translate with the macOS Translation framework—no third-party translation service required
- Native SwiftUI overlay, menu bar controls, automatic language detection, and translation copying
- Localized interface in Simplified Chinese, Traditional Chinese, English, Japanese, and Korean
- System-localized language names and 19 commonly used translation languages

## Requirements

- macOS 26.0+
- Xcode 26.0+
- Accessibility permission for translating selected text
- Screen & System Audio Recording permission for screen-region OCR

Open `qoq.xcodeproj` in Xcode and run the app. macOS may ask to download the required language resources the first time you translate a language pair.
