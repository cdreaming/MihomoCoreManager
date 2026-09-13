# v1.3.0 Validation

发布/交付前执行：

```bash
python3 scripts/generate-app-icon.py
python3 scripts/build-source-manifest.py --write
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
python3 scripts/release-preflight.py
bash scripts/build-portable-installer.sh
```

Linux/ChatGPT Web 交付必须确认：

- `VERSION=1.3.0`、`BUILD_NUMBER=1300`。
- GoWebUI portable 文件名为 `MihomoCoreManager-v1.3.0-GoWebUI-arm64-portable-installer.zip`。
- ZIP 内 App 为 arm64 Mach-O，Info.plist 为 `1.3.0 / 1300`，`MCMBuildVariant=GoWebUI`。
- 16–1024 px AppIcon 齐全。
- Go tests/vet 与 Swift syntax parse 通过。

GitHub/macOS arm64 额外执行 `bash scripts/simulate-release.sh`，并必须同时产出：

- `MihomoCoreManager-v1.3.0-GoWebUI-arm64.pkg`
- `MihomoCoreManager-v1.3.0-SwiftUI-arm64.pkg`

两者命名不得省略实现名。
