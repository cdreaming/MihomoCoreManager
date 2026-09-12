# QA v1.2.8

## 版本与发布元数据

- [ ] `VERSION` 为 `1.2.8`。
- [ ] Xcode `MARKETING_VERSION=1.2.8`、`CURRENT_PROJECT_VERSION=128`。
- [ ] portable runtime `appVersion=1.2.8`、`buildNumber=128`。
- [ ] `python3 scripts/validate-source.py` 通过。
- [ ] `python3 scripts/build-source-manifest.py --check` 通过。
- [ ] `python3 scripts/release-preflight.py` 通过。
- [ ] `bash scripts/simulate-release.sh` 通过。

## v1.2.8 运行稳定性回归

- [ ] 启动 portable 安装版，关闭主窗口后状态栏继续存在且完整下拉菜单可正常打开。
- [ ] 从状态栏选择“打开主窗口”后，窗口可立即拖动、缩放、最小化，再次关闭/打开至少 10 次不进入恢复模式。
- [ ] `Runtime/menubar.log` 在正常关闭/重开路径中不出现 menu shell crash；单次异常退出时完整 shell 会自动重启一次，再次失败才进入恢复 shell。
- [ ] 恢复 shell 主窗口仍可通过顶部拖拽区移动，并可重复关闭/打开。
- [ ] 损坏/临时清空 `Runtime/proxies.json` 或状态快照时，状态栏 shell 不退出；快照恢复后菜单继续刷新。

## 既有功能回归

- [ ] 状态栏本体仍为上传在上、下载在下的双行实时网速；下拉菜单上传/下载为单行。
- [ ] 代理组区域前后分隔、懒加载、测速、线路切换正常。
- [ ] 状态栏选择线路后，顶层代理组后缀立即更新，延迟权威刷新不会错误回滚新选择。
- [ ] Cloudflare 530 / Error 1033 临时故障继续使用最近成功快照。
- [ ] 主窗口保持 256pt 左侧导航 + 右侧内容，无独立视觉标题栏。
- [ ] Core Secret / Controller Secret 继续走既有 Keychain / Bearer 鉴权路径。
- [ ] 未开启 `Allow Insecure HTTP` 时拒绝明文 HTTP；TLS 校验不可关闭。
- [ ] GET/HEAD 临时错误重试有上限，POST/PUT 不自动重试。
