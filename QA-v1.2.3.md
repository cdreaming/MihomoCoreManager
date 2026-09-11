# QA v1.2.3

## 代理切换

- [ ] 未配置 Direct Core Controller URL 时显示明确错误。
- [ ] Secret 错误时能显示 Controller 返回错误。
- [ ] `GET /configs` 可读取 rule/global/direct。
- [ ] 三种运行模式均可切换，并立即更新选中态。
- [ ] `GET /proxies` 可展示代理组及当前节点。
- [ ] Selector / URLTest / Fallback 组可选择组内代理。
- [ ] 代理组名称包含空格、斜杠等字符时 URL 路径编码正确。
- [ ] 代理详情可显示类型、alive、最近 delay、UDP/XUDP/TFO。
- [ ] 切换代理后当前节点状态刷新。
- [ ] 切换服务器 Profile 后代理数据重新加载。

## 构建

- [ ] `python3 scripts/validate-source.py`
- [ ] `python3 scripts/build-source-manifest.py --check`
- [ ] `CGO_ENABLED=0 go test ./...`
- [ ] 全部 Swift 文件通过 `swiftc -frontend -parse`
- [ ] portable installer 交叉编译为 `darwin/arm64`
