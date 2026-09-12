# Mihomo Core Manager v1.3.0

v1.3.0 固化双实现开发/发布工作流，并更换现代化应用图标。

## 版本

- App: `1.3.0`
- Build: `1300`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: 14.0
- GoWebUI build toolchain: Go `1.23.2`

## 新图标

- 新增蓝青 → 蓝紫渐变的现代 macOS 圆角图标，中心为折叠丝带式 `M` 标记。
- `branding/AppIcon-master-1024.png` 是唯一设计母版。
- `scripts/generate-app-icon.py` 从母版生成 Xcode AppIcon 全尺寸以及 GoWebUI 内嵌品牌图。
- SwiftUI/AppKit 与 Go/AppKit/Web UI 共用同一套应用图标资产。

## 固定开发工作流

每个版本按以下方式交付：

`开发 → 源代码 + GoWebUI portable → 上传 GitHub → GitHub 同时生成 GoWebUI.pkg + SwiftUI.pkg`

用户可以自行安装验证；发现 Bug 或不符合预期的地方，在下一版本继续修改，不再设置“确认发布”阻塞点。

## 双实现 Release

GitHub Release 明确发布两个独立实现：

- `MihomoCoreManager-v1.3.0-GoWebUI-arm64.pkg`
  - Go + AppKit/JXA + WKWebView/Web UI
  - 与 ChatGPT Web 可直接构建的 portable preview 共用 `scripts/build-gowebui-app.sh`
- `MihomoCoreManager-v1.3.0-SwiftUI-arm64.pkg`
  - SwiftUI + AppKit 原生实现
  - 在 Apple Silicon macOS/Xcode runner 构建

两者共享 `VERSION`、`BUILD_NUMBER`、AppIcon 和 Release Notes，但 UI 源码独立，文件名明确区分。

## GoWebUI 一致性门禁

- 新增 `GoWebUI-RELEASE-LOCK.json`。
- Lock 覆盖 Go runtime、Web UI、图标母版/生成尺寸、共享 App builder、portable 打包脚本与 GitHub GoWebUI PKG 打包脚本。
- ChatGPT portable 与 GitHub GoWebUI.pkg 均调用同一个 `scripts/build-gowebui-app.sh`。
- 构建固定 Go `1.23.2`；锁或工具链不一致时直接失败。

这样需要严格比较 UI 时，比较对象应为：

`ChatGPT GoWebUI portable ↔ GitHub GoWebUI.pkg`

SwiftUI.pkg 是第二套独立原生实现，不作为 GoWebUI 像素级一致性的证明。
