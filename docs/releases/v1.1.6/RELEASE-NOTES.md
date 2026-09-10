# Mihomo Core Manager v1.1.6

v1.1.6 将按钮交互直接恢复到 v1.0.9 的实现方式。

## 按钮修复

- `DashboardActionButtonStyle` 直接采用 v1.0.9 源码实现。
- 主按钮按下时使用 v1.0.9 的背景变化和 `0.985` 缩放。
- 不使用显式 press/release animation。
- 删除 v1.1.5 的 `DashboardPressButtonStyle`。
- 导航、Popover、链接和关闭类按钮恢复 `.plain`。

## 保留 v1.1.5 修复

- 设置页纵向排列。
- “App 与状态栏”双列分组。
- 概览与 Core 配对卡片下沿对齐。
- 运行日志与其他页面统一 UI。
- 多服务器、Keychain、订阅、更新与 portable runtime 保持不变。

版本：App v1.1.6 (build 116)，API 兼容基线 v4.0.0。
