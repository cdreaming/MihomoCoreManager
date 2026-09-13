# QA — MihomoManager v1.3.2

## 自动化门禁

- [ ] `go test ./...`（portable-runtime）
- [ ] `go vet ./...`（portable-runtime）
- [ ] Swift 源码 parse/typecheck 门禁通过
- [ ] `python3 scripts/validate-source.py`
- [ ] `python3 scripts/build-gowebui-release-lock.py --check`
- [ ] GoWebUI Mach-O `LC_UUID` 非零

## macOS 15+ 真机回归

1. 安装 GoWebUI，首次访问局域网时允许“本地网络”。
2. Controller `192.168.x.x:9090` 可直接读取状态、代理并切换代理。
3. Core 服务面板 `192.168.x.x:29090` 可读取状态、订阅、日志并执行服务动作。
4. MetaCubeXD 局域网地址可打开。
5. SSH 目标留空时，任何 Controller/Management 失败都不得触发 `/usr/bin/ssh`。
6. 显式填写 SSH 目标后，仅在 API 失败时才允许 systemd/journalctl 回退。
7. 保存 Management Secret 与 Controller Secret 后退出并重启 App，凭据仍可正确读取。
8. 从 v1.3.1 升级后，旧 `cc.kkr.MihomoManager` Management Secret 自动迁移并继续可用。
