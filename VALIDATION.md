# Validation Report — v1.1.4 macOS App

- App 版本统一为 `1.1.4`，Xcode build number 与 portable build number 统一为 `114`。
- 修复 `OverviewView.swift` 中 Xcode 16.4 无法编译的混合 `frame` overload。
- 全部 Swift 源文件通过 `swiftc -parse` 语法解析检查。
- 源码校验新增 SwiftUI `frame` 固定尺寸 / flexible 尺寸混用门禁。
- 概览、Core 控制、订阅管理、设置页面继续保留 v1.1.3 的统一布局设计。
- 原生菜单栏继续保持 v1.0.9 样式，主窗口继续保留紧凑标题栏。
- portable runtime 与 unsigned Release 流程保持不变。
