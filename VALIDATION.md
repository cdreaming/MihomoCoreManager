# v1.3.1 Validation

发布/交付前执行：

```bash
python3 scripts/generate-app-icon.py
python3 scripts/build-gowebui-release-lock.py --write
python3 scripts/build-source-manifest.py --write
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
python3 scripts/release-preflight.py
bash scripts/build-portable-installer.sh
```

Linux/ChatGPT Web 交付必须确认：

- `VERSION=1.3.1`、`BUILD_NUMBER=1301`。
- GoWebUI portable 文件名为 `MihomoCoreManager-v1.3.1-GoWebUI-arm64-portable-installer.zip`。
- ZIP 内 App 为 arm64 Mach-O，Info.plist 为 `1.3.1 / 1301`，`MCMBuildVariant=GoWebUI`。
- `branding/MihomoCoreManager-2.png` 为图标原始来源；16–1024px AppIcon 与 GoWebUI 界面图标由生成脚本同步产出。
- SwiftUI 与 GoWebUI 右侧内容顶部不高于左侧品牌区；“服务设置”导航名一致。
- GoWebUI 局域网直连、macOS 本地解析回退及 Cloudflare Tunnel 失败退避测试通过。
- Go tests/vet 与可用环境下的 Swift syntax/typecheck 通过。

GitHub/macOS arm64 额外执行 `bash scripts/simulate-release.sh`，并必须同时产出：

- `MihomoCoreManager-v1.3.1-GoWebUI-arm64.pkg`
- `MihomoCoreManager-v1.3.1-SwiftUI-arm64.pkg`

两者命名不得省略实现名。
