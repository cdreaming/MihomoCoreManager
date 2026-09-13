# QA — MihomoManager v1.3.5

## 自动检查

- [ ] `python3 scripts/validate-source.py`
- [ ] `python3 scripts/build-gowebui-release-lock.py --check`
- [ ] `go test ./...`
- [ ] GoWebUI darwin/arm64 cross-build成功，Mach-O `LC_UUID` 非零/已修复
- [ ] GoWebUI portable installer ZIP 完整且版本为 1.3.5 (1305)

## macOS 手工检查

1. SwiftUI 和 GoWebUI 下拉菜单顶部均为“大 LOGO 左侧跨两行”：SwiftUI 46pt、GoWebUI 44pt；右侧第一行显示 Core/版本/状态，第二行显示上传/下载网速。
2. SwiftUI 和 GoWebUI 状态栏常驻图标都显示同一 LOGO；启用网速时 LOGO 在左、双行网速在右，状态点不覆盖 LOGO。
3. 关闭“主窗口”后，状态栏图标和下拉菜单继续存在；从状态栏“主窗口”可再次打开。
4. 点击状态栏“退出 MihomoManager”后，主窗口、状态栏项与 GoWebUI runtime（如适用）全部退出。
5. “显示图标 / 显示运行状态 / 显示网速 / 仅显示图标”组合仍可正常切换。
