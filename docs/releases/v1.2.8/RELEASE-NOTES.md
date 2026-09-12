# Mihomo Core Manager v1.2.8

v1.2.8 以 v1.2.7 为稳定基线，重点修复 portable 安装版关闭主窗口后从状态栏恢复时出现的窗口不可拖动、状态栏进程异常退出并进入“恢复模式：状态栏渲染已降级”问题。

## 版本

- App: `1.2.8`
- Build: `128`
- Xcode `MARKETING_VERSION`: `1.2.8`
- Xcode `CURRENT_PROJECT_VERSION`: `128`
- portable runtime: `1.2.8 / 128`

## 运行稳定性修复

- portable 主窗口显式设置 `releasedWhenClosed=false`。关闭窗口只隐藏/关闭可见窗口，不再让 AppKit 回收仍被状态栏 shell 持有的 `NSWindow`，避免后续“打开主窗口”访问失效 Objective-C 对象导致 `osascript` 退出。
- 从状态栏重新打开窗口前会重新确认 `movable=true` 与 `movableByWindowBackground=true`，并继续使用顶部 22px 原生 `performWindowDragWithEvent:` 拖拽区。
- 状态栏 shell 单次异常退出后先自动重启一次完整模式；只有连续第二次失败才启动最小恢复 shell，降低偶发 AppKit/JXA 错误导致永久降级的概率。
- 初次服务器菜单、代理菜单和状态刷新改为 fail-soft；本地快照损坏、暂时不完整或 AppKit 菜单刷新异常不会直接中止状态栏进程。
- 恢复模式窗口同步使用 `releasedWhenClosed=false`、可移动窗口属性和原生拖拽区。即使确实进入恢复模式，也不会再出现窗口无法拖动。

## 保持不变

- 状态栏本体继续保持上传在上、下载在下的双行实时网速布局；下拉菜单中的上传/下载保持单行。
- 代理组懒加载、测速、切换即时后缀更新、Cloudflare 530 / Error 1033 最近成功快照回退保持不变。
- Controller Secret / Core Secret、HTTP/TLS 安全策略以及 v1.2.7 的发布硬门禁保持不变。
