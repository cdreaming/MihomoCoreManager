# MihomoManager v1.3.3

v1.3.3 以 v1.3.2 为基线，重点统一 SwiftUI/GoWebUI 的后端连接状态展示与 Core 控制优先级说明，不改变 v1.3.2 已确立的 API-first、显式 SSH 才回退 systemd 的服务策略。

## 版本

- App: `1.3.3`
- Build: `1303`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: 14.0
- GoWebUI official release toolchain: Go `1.26.8`

## 变更

- SwiftUI 侧栏左下角不再显示 `SwiftUI :端口` / `SwiftUI · Core`；状态成功时显示“后端已连接 · <manager>”，持续失败后显示“后端未连接 · 检查设置”，与 GoWebUI 的运行时文案一致。
- SwiftUI Core 控制页“服务控制”中的优先级说明改为标题 + 四行缩进文本，避免长段落换行导致阅读顺序不清。
- GoWebUI 同步修正 Core 控制页旧的 systemd 优先说明，统一为：
  1. 重启/热重载先走 Mihomo Controller API；
  2. 服务生命周期与日志随后走 Core 服务面板 API；
  3. 避免因局域网直连失败而自动触发 SSH 认证；
  4. 只有显式配置 SSH 目标时才尝试 `mihomo.service/systemd`。
- 根目录加入 `HomePage.png` 和 `CorePage.png`，README 增加界面预览。

## 构建说明

ChatGPT/Linux 开发交付继续提供“源码 + GoWebUI portable installer”。正式 SwiftUI/GoWebUI `.pkg` 仍由 macOS/Xcode Release 流水线生成。
