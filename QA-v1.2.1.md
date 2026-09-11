# Mihomo Core Manager v1.2.1 QA

## GitHub/Xcode 正式状态栏

- [ ] GitHub Actions 生成的 `MihomoCoreManager-v1.2.1-arm64.pkg` 安装后，状态栏本体显示上下两行实时网速，而不是单个数字。
- [ ] 上传位于上半行、下载位于下半行，整个速度块靠下。
- [ ] 两行数字从同一左边缘开始，固定预留 4 个等宽字符位。
- [ ] 单位在 `B/s / KB/s / MB/s / GB/s / TB/s` 之间切换时位置稳定。
- [ ] 状态栏本体没有 `↑ / ↓` 箭头。
- [ ] 图标/状态/网速开关及“仅图标”模式切换后，状态栏仍可点击并打开 v1.1.9 自定义面板。

## 回归

- [ ] v1.1.9 自定义紧凑下拉面板视觉与功能保持不变。
- [ ] portable arm64 安装包仍维持 v1.2.0 已验证的 AppKit 双行状态栏效果。
- [ ] GitHub Release 同时包含正式 `.pkg/.zip` 和 `arm64-portable-installer.zip`。
