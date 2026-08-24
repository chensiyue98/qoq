# QoQ

**简体中文** | [English](README.md)

一款仅使用 macOS 系统能力的原生翻译菜单栏应用。

## 功能

- `⌃ Q`：读取当前应用中选中的文字并翻译
- `⌃ W`：框选屏幕区域，使用 Vision OCR 识别后翻译
- `⌃ E`：框选屏幕区域，仅使用 Vision OCR 提取文字并复制到剪贴板
- 可在设置中录制并保存三项自定义全局快捷键
- 使用 macOS Translation framework，不依赖第三方翻译服务
- 原生 SwiftUI 浮层、菜单栏入口、自动语言检测与译文复制
- 界面支持简体中文、繁體中文、English、日本語和한국어
- 翻译语言名称使用系统本地化显示，内置 19 种常用翻译语言

## 安装

### Homebrew

```bash
brew tap chensiyue98/tap
brew install --cask qoq
```

使用以下命令升级到最新版本：

```bash
brew update
brew upgrade --cask qoq
```

### GitHub Releases

从 [GitHub Releases](https://github.com/chensiyue98/qoq/releases) 下载最新的 `QoQ-<版本号>.zip`，解压后将 `QoQ.app` 移动到“应用程序”文件夹。

### Mac App Store

Mac App Store 版本将在审核通过后提供。正式上架后会在这里补充商店直达链接。

### 从源码构建

克隆仓库，使用 Xcode 打开 `qoq.xcodeproj`，选择 `QoQ-Direct` Scheme 后运行。

## 要求

- macOS 26.0+
- Xcode 26.0+
- 首次划词翻译需授予“辅助功能”权限
- 首次框选识别需授予“屏幕与系统音频录制”权限

首次翻译某个语言组合时，系统可能提示下载对应语言包。
