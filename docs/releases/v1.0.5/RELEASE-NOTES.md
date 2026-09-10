# Mihomo Core Manager v1.0.5

v1.0.5 继续兼容 **Mihomo Core 管理面板 v4.0.0**，本次重点继续优化左侧后端选择器，并修复即时安装版状态栏实时网速不显示的问题。

## 后端选择器 UI

- 左侧新增“管理后端”分区标识，选择器与主品牌使用同一套 M 图标与 Dashboard 配色。
- 触发器高度调整为 64pt/px，明确分层显示产品、当前服务器和 Host/Port。
- 展开按钮独立成圆形控制，打开状态使用轻量强调色，不再像系统紧凑下拉框。
- 下拉面板服务器行调整为 60pt/px；当前服务器使用选中描边和背景。
- “未设置 Core Secret”改为独立警示标记，不再拼接在服务器名称后造成大量省略号。
- portable 下拉面板宽度扩大到 292px，在 230px 侧栏中仍可向右展开，名称和端点有更多可用空间。

## 状态栏网速修复

- 即时安装版不再通过动态 `NSImage` 承载两行速度文本。
- 改为 `QuartzCore` / `CATextLayer` 直接在 `NSStatusBarButton` 内绘制：左侧是状态点与 `Running / Stopped / Offline`，右侧是独立的两行 `↑ upload` / `↓ download`。
- `NSStatusItem.length` 根据“显示运行状态 / 显示网速 / 仅显示图标”自动计算，避免速度区域被系统裁切。
- 本地 `status.json` 增加 `_menu_updated_unix_ms` 时间戳，菜单栏会检查快照新鲜度。
- 如果快照读取失败或超过 5 秒未更新，状态栏会自动触发一次 loopback `/local/status` 恢复，不会因为一次文件读取失败长期不显示速度。
- 下拉菜单的上传、下载值改成两个独立只读项目，实时值更稳定。

## 保留

- 标准 macOS 标题栏拖动。
- 设置 Tab、常驻页面、异步流量图与状态缓存优化。
- 多服务器 / 跨机管理。
- Core Secret `⌘V` 与显式粘贴。
- Apple Silicon arm64 与 GitHub Actions 正式签名/公证/PKG 发布流程。

版本：App v1.0.5 (build 105)，API 兼容基线 v4.0.0。
