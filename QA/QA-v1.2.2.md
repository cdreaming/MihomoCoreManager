# Mihomo Core Manager v1.2.2 QA

## GitHub Actions / Release

- [ ] push/PR 的 `macOS CI` 中 `配置 portable Go 工具链` 成功，并能输出 Go 1.23.x 或兼容 `go.mod` 的版本。
- [ ] `Portable release parity test` 能完成 `CGO_ENABLED=0 go test ./...` 与 `scripts/build-portable-installer.sh`。
- [ ] tag `v1.2.2` 的 `macOS Release` 不再出现 `Go is required`。
- [ ] Release 同时包含 `MihomoCoreManager-v1.2.2-arm64.pkg`、`MihomoCoreManager-v1.2.2-arm64.zip`、`MihomoCoreManager-v1.2.2-arm64-portable-installer.zip`、Release Notes 和 `SHA256SUMS.txt`。
- [ ] 在线回读 `SHA256SUMS.txt` 校验全部通过。

## 状态栏回归

- [ ] GitHub/Xcode 正式包仍显示上传在上、下载在下的双行网速。
- [ ] 数字左对齐并预留 4 位，单位自动切换，状态栏本体无箭头。
- [ ] v1.1.9 自定义下拉面板无视觉/功能回退。
- [ ] portable 安装包仍维持 v1.2.0 已验证的 AppKit 状态栏效果。
