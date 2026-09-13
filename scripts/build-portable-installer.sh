#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER")"
DIST="$ROOT/dist-portable"
STAGE="$ROOT/build/portable-installer"
PACKAGE_NAME="MihomoManager-v${VERSION}-GoWebUI-arm64-portable-installer"
PACKAGE_DIR="$STAGE/$PACKAGE_NAME"
APP="$PACKAGE_DIR/MihomoManager.app"
OUT="$DIST/$PACKAGE_NAME.zip"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid BUILD_NUMBER: $BUILD_NUMBER" >&2; exit 1; }

rm -rf "$STAGE" "$DIST"
mkdir -p "$PACKAGE_DIR" "$DIST"

# Critical v1.3.0 contract: the quick preview and GitHub GoWebUI.pkg use the
# same app-bundle builder. There is no second Go/Web UI implementation.
bash "$ROOT/scripts/build-gowebui-app.sh" "$APP"

cat > "$PACKAGE_DIR/Install-MihomoManager.command" <<'CMD'
#!/bin/zsh
set -euo pipefail
HERE="${0:A:h}"
SOURCE="$HERE/MihomoManager.app"
TARGET="/Applications/MihomoManager.app"
LEGACY_TARGET="/Applications/MihomoCoreManager.app"

echo "MihomoManager GoWebUI portable installer"
echo "Source: $SOURCE"
echo "Target: $TARGET"

if [[ ! -d "$SOURCE" ]]; then
  echo "Installer payload is incomplete: MihomoManager.app is missing." >&2
  exit 1
fi

/usr/bin/pkill -x MihomoManager >/dev/null 2>&1 || true
/usr/bin/pkill -x MihomoCoreManager >/dev/null 2>&1 || true
if [[ -e "$TARGET" ]]; then
  echo "Replacing existing installation…"
  sudo /bin/rm -rf "$TARGET"
fi
if [[ -e "$LEGACY_TARGET" ]]; then
  echo "Removing legacy MihomoCoreManager.app after rename…"
  sudo /bin/rm -rf "$LEGACY_TARGET"
fi

echo "Installing to /Applications…"
sudo /usr/bin/ditto "$SOURCE" "$TARGET"
sudo /usr/bin/codesign --force --deep --sign - "$TARGET" >/dev/null 2>&1 || true

echo "Installation complete."
echo "This preview is ad-hoc/unsigned and not notarized; macOS may require right-click > Open on first launch."
/usr/bin/open "$TARGET" || true
printf "\nPress any key to close…"
read -k 1
printf "\n"
CMD
chmod 0755 "$PACKAGE_DIR/Install-MihomoManager.command"

cat > "$PACKAGE_DIR/Uninstall-MihomoManager.command" <<'CMD'
#!/bin/zsh
set -euo pipefail
TARGET="/Applications/MihomoManager.app"
/usr/bin/pkill -x MihomoManager >/dev/null 2>&1 || true
if [[ -e "$TARGET" ]]; then
  sudo /bin/rm -rf "$TARGET"
  echo "Removed $TARGET"
else
  echo "MihomoManager.app is not installed in /Applications."
fi
printf "\nPress any key to close…"
read -k 1
printf "\n"
CMD
chmod 0755 "$PACKAGE_DIR/Uninstall-MihomoManager.command"

cat > "$PACKAGE_DIR/README-安装.txt" <<EOF
MihomoManager v${VERSION} (build ${BUILD_NUMBER}) GoWebUI portable preview

用途：ChatGPT Web / Linux 环境可以直接构建，用于快速安装验证 UI 和功能。

正式 GitHub Release 会并行生成：
  - MihomoManager-v${VERSION}-GoWebUI-arm64.pkg
  - MihomoManager-v${VERSION}-SwiftUI-arm64.pkg

GoWebUI portable 与 GitHub GoWebUI.pkg 都调用 scripts/build-gowebui-app.sh，
共享同一份 Go/AppKit/Web UI 源码、HTML/CSS/JS、版本和 AppIcon 资产。
SwiftUI.pkg 是另一套原生 SwiftUI/AppKit 实现，文件名明确区分，不要求像素级一致。

1. 需要 Apple Silicon Mac 和 macOS 14.0+。
2. 双击 Install-MihomoManager.command 安装到 /Applications。
3. 此 preview 未做 Developer ID 签名/公证；首次启动若被 Gatekeeper 拦截，请右键 App -> 打开。
EOF

PACKAGE_DIR="$PACKAGE_DIR" OUT="$OUT" python3 - <<'PY'
from pathlib import Path
import os, zipfile
src = Path(os.environ['PACKAGE_DIR'])
out = Path(os.environ['OUT'])
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for path in sorted(src.rglob('*')):
        if path.is_dir():
            continue
        rel = Path(src.name) / path.relative_to(src)
        info = zipfile.ZipInfo.from_file(path, arcname=rel.as_posix())
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = (path.stat().st_mode & 0xFFFF) << 16
        with path.open('rb') as f:
            zf.writestr(info, f.read(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
PY

ls -lh "$OUT"
echo "GoWebUI portable installer: PASS"
