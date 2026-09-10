# Mihomo Core Manager v1.1.5 QA

- v1.1.4 上传成品：1.1.4 build 114，arm64 Mach-O。
- Swift parse：14/14 PASS。
- Button 声明遍历：59 个。
- Source validator：source validation: PASS (v1.1.5, arm64, menu/API/settings/release gates)
- Source manifest：source manifest: PASS
- Go tests：ok  	cc.kkr/MihomoCoreManagerPortable	0.313s
- Portable mock API：17 路由 PASS。
- v1.0.9 按压参考：0.085/0.025 背景 + 0.985 scale。
- 主 Dashboard 无裸 .buttonStyle(.plain)。
- Settings 顺序：服务器 → 服务器连接 → Core 配置 → App 与状态栏 → 操作区。
- App 与状态栏：双列分组。
- Overview 配对高度 336pt；Core 配对高度 300pt。
- ViewThatFits 重复按钮树已移除。

|Window|Inner|Traffic|Pair|
|---:|---:|---:|---:|
|1000|713|365|349.5|
|1100|813|465|399.5|
|1220|933|585|459.5|
|1440|1153|805|569.5|
|1680|1393|1045|689.5|

## 原生安装包
- 当前容器没有 xcodebuild/pkgbuild，无法编译包含本次 SwiftUI 修改的真实 v1.1.5 .app/.pkg。
- 不会把 v1.1.4 二进制改名冒充 v1.1.5。
- scripts/build-release.sh --unsigned 可在 Apple Silicon macOS 上直接生成 v1.1.5 zip/pkg。
