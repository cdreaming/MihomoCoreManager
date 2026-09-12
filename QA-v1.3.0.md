# QA v1.3.0

## Shared release inputs

- [ ] `VERSION` = `1.3.0`.
- [ ] `BUILD_NUMBER` = `1300`.
- [ ] Xcode `MARKETING_VERSION=1.3.0`, `CURRENT_PROJECT_VERSION=1300`.
- [ ] GoWebUI runtime reports `1.3.0 / 1300`.
- [ ] `GoWebUI-RELEASE-LOCK.json` passes `python3 scripts/build-gowebui-release-lock.py --check`.
- [ ] Go toolchain is exactly `go1.23.2`.

## Icon

- [ ] Dock/Finder icon uses the new blue/cyan/violet folded-ribbon M design.
- [ ] SwiftUI and GoWebUI use the same AppIcon master/assets.
- [ ] GoWebUI sidebar uses the same modern icon instead of a plain letter tile.
- [ ] Icon remains readable at 16, 32, 64, 128, 256, 512 and 1024 px.

## GoWebUI portable

- [ ] `MihomoCoreManager-v1.3.0-GoWebUI-arm64-portable-installer.zip` installs on Apple Silicon macOS 14+.
- [ ] Info.plist contains `MCMBuildVariant=GoWebUI`.
- [ ] Status bar, proxy selection, subscriptions, logs, settings and main window regressions remain functional.
- [ ] Main sidebar version order remains `本程序版本 / Core 版本 / Core 面板 / MetaCubeXD`.

## GitHub dual package release

- [ ] GitHub Release produces `MihomoCoreManager-v1.3.0-GoWebUI-arm64.pkg`.
- [ ] GitHub Release produces `MihomoCoreManager-v1.3.0-SwiftUI-arm64.pkg`.
- [ ] GoWebUI.pkg calls the same `scripts/build-gowebui-app.sh` as the portable preview.
- [ ] SwiftUI.pkg is built through Xcode on an arm64 `macos-15` runner.
- [ ] Online Release SHA-256 verification passes.
