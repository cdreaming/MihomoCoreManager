# Mihomo Core Manager v1.1.4

v1.1.4 是 v1.1.3 统一布局版本的构建修复版。

## 构建修复

- 修复 Xcode 16.4 编译 `OverviewView.swift` 时的 `extra argument 'minHeight' in call`。
- 原问题来自 `.frame(width: 334, minHeight: 336, alignment: .top)`，该参数组合不存在对应 SwiftUI overload。
- 现已拆分为 `.frame(width: 334)` 与 `.frame(minHeight: 336, alignment: .top)`，视觉布局目标不变。
- 新增源码静态门禁，检查 SwiftUI 固定 frame 与 flexible frame 参数被错误混用的情况。

## 保留内容

- 保留 v1.1.3 已完成的统一页面布局。
- 保留紧凑标题栏。
- 保留 v1.0.9 菜单栏标签布局。
- 保留多服务器 Profile、Keychain Secret、订阅热重载、portable runtime 与 unsigned Release 流程。

版本：App v1.1.4 (build 114)，API 兼容基线 v4.0.0。
