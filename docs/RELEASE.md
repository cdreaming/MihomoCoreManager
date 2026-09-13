# macOS v1.3.1 双实现发布流程

v1.3.0 起固定维护两套实现，并明确区分用途和资产名称。

## 开发交付

ChatGPT Web / Linux 环境执行：

```bash
python3 scripts/build-gowebui-release-lock.py --check
bash scripts/build-portable-installer.sh
```

交付：

- 完整项目源码
- `MihomoManager-v1.3.1-GoWebUI-arm64-portable-installer.zip`

portable 用于快速安装查看 UI/功能；用户自行验收，问题进入下一版本修复，不设置额外“确认发布”门槛。

## GitHub Release

`macos-15-intel` runner 交叉构建 arm64，并执行统一入口：

```bash
bash scripts/simulate-release.sh
```

真实 Release 构建：

```bash
bash scripts/build-release.sh --unsigned
```

`build-release.sh` 并行编排两个实现：

1. GoWebUI
   - `scripts/build-gowebui-release.sh`
   - App bundle 必须由 `scripts/build-gowebui-app.sh` 生成。
   - portable preview 也必须调用同一个 App builder。
   - 正式文件：`MihomoManager-v1.3.1-GoWebUI-arm64.pkg`
2. SwiftUI
   - `scripts/build-swiftui-release.sh`
   - Xcode Release / arm64 / macOS 14+。
   - 正式文件：`MihomoManager-v1.3.1-SwiftUI-arm64.pkg`

## GoWebUI 防漂移规则

`GoWebUI-RELEASE-LOCK.json` 是 preview 与 GitHub GoWebUI.pkg 的输入锁。它覆盖运行时、HTML/CSS/JS、图标、共享 App builder 和两条 GoWebUI 打包路径。

发布前必须执行：

```bash
python3 scripts/build-gowebui-release-lock.py --check
```

同时固定 Go `1.23.2`。任何锁文件或工具链漂移都必须阻止发布。需要修改 GoWebUI 时，修改完成后由开发者明确运行 `--write` 重建 lock，再重新测试。

## 一致性定义

- **严格 UI 对照：** ChatGPT `GoWebUI portable` ↔ GitHub `GoWebUI.pkg`。
- **SwiftUI.pkg：** 独立原生实现，要求功能和设计目标一致，但不承诺与 GoWebUI 像素级相同。
- 两个 PKG 都安装为 `/Applications/MihomoManager.app`，属于二选一安装；后安装版本覆盖先安装版本。
## GitHub API 5xx 与已有 tag 恢复

正常发布由 `.github/workflows/release.yml` 调用 `scripts/github-release.sh`。Release 是否存在通过 REST 探测确认：只有明确 HTTP 404 才创建；HTTP 5xx、限流或网络错误只重试，避免把 GitHub 服务端故障误当成“不存在”。

如果 tag 已经存在，而之前的 Actions 在 GitHub Release API 阶段失败（例如 `HTTP 500 .../releases`），不要强制移动 tag。先尝试在原失败运行中 **Re-run failed jobs**；如需使用修复后的发布逻辑，在 Actions 手工运行 **Retry Existing GitHub Release**，输入例如 `v1.3.1`。该流程会：

1. 从当前 workflow 分支复制新版 `github-release.sh`；
2. 单独 checkout 精确的已有 `v1.3.1` tag 作为构建源码；
3. 重新执行双实现 release simulation；
4. 对 create/edit/upload/download 使用 5xx 安全重试；
5. 在线回读并校验 `SHA256SUMS.txt` 及两套 pkg。

该恢复流程不会删除、移动或重新创建已有 tag。

