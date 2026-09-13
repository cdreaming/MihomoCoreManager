# MihomoManager v1.3.2 修复审计

## 根因 1：GoWebUI Mach-O 缺失 LC_UUID

v1.3.1 固定 Go 1.23.2，并使用 `-buildid=`。该链路产生的 GoWebUI arm64 Mach-O 没有 `LC_UUID`。macOS 15+ 对 App Bundle 的本地网络隐私识别会因此异常，表现为局域网 TCP 在应用内先报 `No route to host`，而 SwiftUI/URLSession 同一地址正常。

v1.3.2 正式构建固定 Go 1.26.8，移除 `-buildid=`，构建后执行 `scripts/verify-macho-uuid.py`；UUID 缺失时正式发布直接失败。recovery 模式只用于无法获得新 Go 工具链的离线恢复构建，会在 post-link 阶段插入确定性 UUID 并再次验证。

## 根因 2：Management Secret Keychain service 不一致

SwiftUI 使用 `cc.kkr.MihomoManager.profile-secret`，v1.3.1 GoWebUI 却使用 `cc.kkr.MihomoManager`。两套实现因此可能保存/读取不同 Keychain 项。

v1.3.2 统一使用 `cc.kkr.MihomoManager.profile-secret`，读取时按以下顺序兼容迁移：

1. `cc.kkr.MihomoManager.profile-secret`
2. `cc.kkr.MihomoManager`（v1.3.1 GoWebUI 错误 service）
3. `cc.kkr.MihomoCoreManager.profile-secret`
4. `cc.kkr.MihomoCoreManager`

写入 Management / Controller Secret 后都立即回读并逐字节比较，失败就返回错误。

## 根因 3：SSH 被自动推断成连接路径

v1.3.1 在 `systemdSSHTarget` 留空时，会从 LAN Management/Controller URL 推断 SSH host。因此一旦局域网 TCP 失败，就会自动调用 `/usr/bin/ssh`，且没有显式用户名时沿用 macOS 当前用户名，形成 `oneking@192.168... Permission denied` 这类误导错误。

v1.3.2 删除全部 SSH host 自动推断。SSH 只有在用户显式填写 target 后才启用。

## v1.3.2 服务优先级

- 状态：Controller → Core 服务面板 `/api/status` → 显式 SSH/systemd。
- 重启：Controller `/restart` → Core 服务面板 `/api/action` → 显式 SSH/systemd。
- 启动/停止：Core 服务面板 `/api/action` → 显式 SSH/systemd。
- 重载：Controller `/configs?force=true` → Core 服务面板 `/api/action` → 显式 SSH/systemd。
- 日志：Core 服务面板 `/api/logs` → 显式 SSH `journalctl`。
- 订阅/项目升级：Core 服务面板 API。
- 代理、模式、测速：Mihomo Controller API。

## GoWebUI 数据位置

- 设置：`~/Library/Application Support/MihomoManager/settings.json`
- Runtime 快照：`~/Library/Application Support/MihomoManager/Runtime/`
- Secret：macOS Keychain，不写入 `settings.json`
- 旧设置迁移：`~/Library/Application Support/MihomoCoreManager/settings.json`
