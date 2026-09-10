# Mihomo Core Manager v1.0.1

## 优化升级

- 修复 Core Secret 在 macOS 即时安装版中无法使用 `⌘V` 粘贴的问题。
- WebKit 壳新增标准 macOS“编辑”菜单：撤销、剪切、复制、粘贴、全选。
- Core Secret 输入区域新增显式“粘贴”按钮；即时安装版通过受本地随机令牌保护的 loopback API 读取剪贴板，仅在用户主动点击时执行。
- 主界面重做为克制的 macOS 风格：标准侧边栏、工具栏、分组表单、系统按钮与分隔线；移除大面积渐变、阴影、强调卡片与装饰性图表。
- 即时安装版 Web UI 同步采用 macOS 风格，并保持 Mihomo Core 管理面板 v4.0.0 的信息结构与 API 兼容性。
- 继续保持 Apple Silicon arm64-only、Keychain Secret 存储、跨机管理和自动签名/公证 Release 流程。

## 兼容性

- App：v1.0.1 (build 101)
- 服务端 API 基线：Mihomo Core 管理面板 v4.0.0
- 最低系统：macOS 14.0
- 架构：Apple Silicon arm64
