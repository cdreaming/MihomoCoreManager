# AI 项目开发模板：macOS 双实现构建规则

适用于需要“AI/Web 环境快速预览 + GitHub macOS 原生构建”的项目。建议固化进 `ai-project-development-template-v1.1.0.zip`。

## 默认交付流程

`AI 开发 -> 交付源代码 + 可在当前 AI 环境直接构建的 Preview installer -> 上传 GitHub -> GitHub 同版本并行构建 Preview 实现的正式 PKG + macOS 原生实现 PKG`

安装确认由项目所有者自行进行，不作为 AI 继续交付/发布源码的阻塞步骤；反馈在下一版本修复。

## 必须存在的共享发布输入

- `VERSION`：语义版本。
- `BUILD_NUMBER`：独立、单调递增的整数，不允许简单删除版本号点号后导致倒退。
- 单一品牌/AppIcon 资产源。
- 单一 Release Notes。

## Preview/正式实现同源规则

若 Preview 实现为 Go/AppKit/Web UI：

1. 只允许一个 App bundle builder，例如 `scripts/build-gowebui-app.sh`。
2. AI 环境 portable installer 必须调用它。
3. GitHub 正式 GoWebUI.pkg 也必须调用它。
4. 禁止复制/重写第二份 HTML/CSS/JS 或第二份 Info.plist/icon 生成逻辑。
5. GitHub 资产名必须明确带实现名，如 `GoWebUI`。

若另有 SwiftUI/AppKit 原生实现：

- 使用独立 Xcode builder。
- 资产名必须明确带 `SwiftUI`。
- 共享版本、build、品牌图标、功能契约，但不宣称两套 UI 像素级一致。

## CI/Release 基线

- CI 与 Release 共享一个顶层模拟脚本。
- Preview runtime：test + vet + race（支持时）+ macOS/arm64 cross compile。
- SwiftUI：Swift syntax parse + Xcode Release build。
- 正式 Release 下载后再次校验 SHA-256 和两个变体文件是否存在。

## 推荐文件命名

- `<App>-v<VERSION>-GoWebUI-arm64-portable-installer.zip`
- `<App>-v<VERSION>-GoWebUI-arm64.pkg`
- `<App>-v<VERSION>-SwiftUI-arm64.pkg`
- `<App>-v<VERSION>-source.zip`

## 模板落地要求

模板应要求项目初始化时选择/声明：

- Preview implementation
- Native implementation（可选）
- 各实现 builder 路径
- GitHub artifact 命名
- VERSION/BUILD_NUMBER 文件
- 共享品牌资产路径

模板生成后的 README/AGENTS/PROJECT-RULES 中应自动写入上述约束，避免后续 AI 会话重新发明发布流程。
