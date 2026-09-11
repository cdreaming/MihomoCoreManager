# QA v1.2.7

## 版本与发布元数据

- [ ] `VERSION` 为 `1.2.7`。
- [ ] Xcode `MARKETING_VERSION=1.2.7`、`CURRENT_PROJECT_VERSION=127`。
- [ ] portable runtime `appVersion=1.2.7`、`buildNumber=127`。
- [ ] `python3 scripts/validate-source.py` 通过。
- [ ] `python3 scripts/build-source-manifest.py --check` 通过。
- [ ] `python3 scripts/release-preflight.py` 通过。
- [ ] `bash scripts/simulate-release.sh` 通过。
- [ ] 模拟发布入口会先基于当前 checkout 执行 manifest `--write -> --check`；故意制造 stale manifest 后仍进入完整编译/测试链路。
- [ ] 历史发布文档 `QA-v1.2.6.md`、`RELEASE-HARDENING-v1.2.6.md` 已纳入 v1.2.7 manifest。

## v1.2.5 成功发布基线回归

- [ ] CI / Release 都调用同一个 `scripts/simulate-release.sh`。
- [ ] `release-preflight.py --strict-macos` 会自行 `manifest --write -> --check`。
- [ ] macOS semantic typecheck 使用 `xcrun --sdk macosx swiftc`、Xcode SDK、`arm64-apple-macos14.0`。
- [ ] Release build 包含 `SWIFT_ENABLE_BATCH_MODE=NO`，并生成 `build/xcodebuild-release.log`。
- [ ] `ContentView.swift` 保留显式 Optional switch、独立 `ProxySortPicker`、拆分的代理组详情 ViewBuilder、macOS 14 双参数 `onChange`。
- [ ] `ProxySortOption` 显式 `Hashable`。
- [ ] portable 背景刷新由 `backgroundWG + goBackground()` 管理；相关 TempDir 测试先 `waitBackground()` 再清理。
- [ ] 目标 Go 竞态回归、shuffle、race、vet 和 Darwin/arm64 交叉编译全部通过。

## 状态栏、代理与主窗口回归

- [ ] 状态栏本体仍为上传在上、下载在下的双行实时网速；下拉菜单上传/下载为单行。
- [ ] 代理组区域前后分隔、懒加载、测速、线路切换正常。
- [ ] 状态栏选择线路后，顶层代理组后缀立即更新，延迟权威刷新不会错误回滚新选择。
- [ ] Cloudflare 530 / Error 1033 临时故障继续使用最近成功快照。
- [ ] 主窗口保持 256pt 左侧导航 + 右侧内容，无独立视觉标题栏；原生拖动、最小化、缩放、关闭正常。
- [ ] Core Secret / Controller Secret 继续走既有 Keychain / Bearer 鉴权路径。
- [ ] 未开启 `Allow Insecure HTTP` 时拒绝明文 HTTP；TLS 校验不可关闭。
- [ ] GET/HEAD 临时错误重试有上限，POST/PUT 不自动重试。
