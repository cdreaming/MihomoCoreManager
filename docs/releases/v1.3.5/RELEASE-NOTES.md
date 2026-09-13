# MihomoManager v1.3.5

v1.3.5 以 v1.3.4 为基线，聚焦 macOS 状态栏 LOGO、状态栏排版和主窗口关闭后的常驻生命周期，并同步修改 SwiftUI 与 GoWebUI 两套实现。

## 版本

- App: `1.3.5`
- Build: `1305`
- Target: Apple Silicon `arm64`
- Minimum macOS: `14.0`
- GoWebUI official release toolchain: Go `1.26.8`

## 变更

- SwiftUI `MenuBarLiveSummary` 改为紧凑双行头部：46pt `BrandLogo` 固定在左侧并跨两行，右侧第一行显示 Core/版本/运行状态，第二行显示上传/下载实时网速。
- SwiftUI 状态栏单图渲染器改为从 `BrandLogo` 加载 LOGO，并将网速块固定在状态项最右侧；运行状态点不再覆盖 LOGO。
- GoWebUI App Bundle 写入 `Contents/Resources/BrandLogo.png`，内容直接来自共享 `AppIcon-128.png`。JXA 下拉菜单头部改为 58pt 自定义视图，44pt 彩色 LOGO 左侧跨两行，右侧两行文字与 SwiftUI 语义一致。
- GoWebUI 状态栏布局同步为 16pt LOGO + 6pt 间距 + 独立状态点 + 53pt 双行网速块。
- SwiftUI 使用 `NSApplicationDelegate` 明确禁止“关闭最后一个窗口即退出”。
- GoWebUI 主菜单壳和恢复壳设置同样的 `applicationShouldTerminateAfterLastWindowClosed = false`，关闭主窗口后状态栏继续常驻并可重新打开主窗口。
- 两个版本的状态栏“退出 MihomoManager”仍会退出整个程序。

## 交付

ChatGPT/Linux 开发环境可直接生成“源码 + GoWebUI portable installer”。SwiftUI/GoWebUI 正式 `.pkg` 仍由 macOS/Xcode Release 流水线构建；本版本源码已同时包含两套实现的对应修改。
