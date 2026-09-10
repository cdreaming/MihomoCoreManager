# Validation Report — v1.1.2 macOS App

- App 版本统一为 `1.1.2`，Xcode build number 与 portable build number 为 `112`。
- 原生菜单栏标签继续保持 v1.0.9 的布局、字号、间距、状态文案与双行网速箭头。
- 主窗口启用 SwiftUI `.windowStyle(.hiddenTitleBar)`，移除标准标题文字和标题栏底板。
- `NSWindow` 同步启用透明标题栏、无分隔线与 `fullSizeContentView`，内容可延伸到顶部。
- macOS 原生红黄绿窗口控制、原生窗口拖拽及背景拖拽保持启用。
- 左侧品牌区使用 38pt 紧凑顶部安全间距，避免内容与窗口按钮重叠。
- v1.1.1 的管理后端选择器、性能优化、portable runtime 与 unsigned Release 流程保持不变。
- Release 自动发布、源码完整性门禁、arm64 版本元数据、API/菜单/设置关键路径保持有效。
