# 余时 App 图标

启动图标使用钴蓝底与白色开放时间环。开放的缺口代表工作之外仍可由自己安排的时间；环末端向前，表达持续推进，但不要求把每一分钟填满。

- 文件：`app-icon.png`
- 规格：1024 × 1024 PNG
- 用途：Android 与 iOS 启动图标源文件
- 生成方式：Codex 内置 ImageGen

## 生成提示词

> Create a minimal production mobile app icon for “余时”. Use one bold white geometric symbol merging an open circular time ring with subtle forward motion. Exact cobalt blue full-bleed background #2F5CF3, pure white mark. Centered inside the launcher safe area. Fully opaque square canvas. No text, gradient, shadow, bevel, texture, border, UI, mockup, or watermark.

界面功能图标使用 `lib/ui/app_icons.dart` 中的统一线性图标，不直接复用启动图标。
