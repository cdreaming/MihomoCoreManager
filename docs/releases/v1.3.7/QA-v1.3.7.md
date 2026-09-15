# QA — MihomoManager v1.3.7

## 版本 / 构建

- [ ] `VERSION=1.3.7`，`BUILD_NUMBER=1307`。
- [ ] SwiftUI / GoWebUI 均保持 arm64，最低 macOS 14.0。

## Core 端口设置

- [ ] Core 控制保持“服务信息 / 服务控制 = 2:3”；MetaCubeXD 已整合进服务控制；下方整行卡按“Core 端口设置 → 项目升级”上下排列。
- [ ] 标准入站端口可启用/禁用并修改 1...65535 端口。
- [ ] Controller、DNS listen 和非受管 listeners（如存在）仅修改端口，不破坏 host/listen。
- [ ] 保存由 Core 服务面板执行配置校验、热重载；失败可回滚。
- [ ] 服务控制备注严格显示为指定两行文本；MetaCubeXD 打开按钮与 URL 同卡显示。
- [ ] SwiftUI 每个端口“保存”按钮固定为相同 88×38pt；GoWebUI 每个端口使用固定宽度的逐项“保存”按钮。

## 线路端口

- [ ] “线路端口”入口位于“代理切换”之后，页面不再重复显示“Core 端口设置”模块。
- [ ] 列表包含端口、端口类型、对应线路/代理组、延时、操作。
- [ ] “运行日志”日志框高度相对原 v1.3.7 增加约 1/3。
- [ ] 每条线路均可单独“刷新延时”，只更新对应行。
- [ ] Provider 节点和代理组均能通过服务面板 v4.1.2 的测速兼容逻辑返回延时。
- [ ] 受管 multiport listener 不提供逐条硬改入口，避免 reconcile 覆盖。

## SSH / 回归

- [ ] 未显式配置 SSH 目标时，Management/Controller 局域网访问失败不会触发 SSH 认证。
- [ ] 显式 SSH 目标下既有 `mihomo.service` 高级回退不受影响。
- [ ] `go test ./...` 通过。
- [ ] `python3 scripts/validate-source.py` 通过。
- [ ] `python3 scripts/build-gowebui-release-lock.py --check` 通过。
- [ ] `python3 scripts/build-source-manifest.py --check` 通过。
