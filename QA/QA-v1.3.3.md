# QA — MihomoManager v1.3.3

## 自动化门禁

- [ ] `go test ./...`（portable-runtime）
- [ ] `go vet ./...`（portable-runtime）
- [ ] Swift 源码 parse 门禁通过
- [ ] `python3 scripts/validate-source.py`
- [ ] `python3 scripts/build-gowebui-release-lock.py --check`
- [ ] GoWebUI arm64 Mach-O `LC_UUID` 非零

## UI 回归

1. SwiftUI 后端可达时，左下角显示“后端已连接 · <manager>”；不可达且状态过期后显示“后端未连接 · 检查设置”。
2. SwiftUI/GoWebUI Core 控制页优先级说明均为四行，顺序与 v1.3.3 Release Notes 一致。
3. SSH 目标留空时，Controller/Management 的 LAN 连接失败不得自动触发 SSH。
4. 显式填写 SSH 目标后，仅在 API 路径失败时允许 systemd/journalctl 最终回退。
5. README 中 `HomePage.png` 与 `CorePage.png` 均可正常显示。
