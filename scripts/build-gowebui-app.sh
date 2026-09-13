#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER")"
APP="${1:-$ROOT/build/GoWebUI/MihomoManager.app}"
BIN="$APP/Contents/MacOS/MihomoManager"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid BUILD_NUMBER: $BUILD_NUMBER" >&2; exit 1; }
command -v go >/dev/null || { echo "Go is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Python 3 is required" >&2; exit 1; }
REQUIRED_GO="go1.26.8"
ACTUAL_GO="$(go version | awk '{print $3}')"
if [[ "$ACTUAL_GO" != "$REQUIRED_GO" ]]; then
  if [[ "${MIHOMO_RECOVERY_ALLOW_LEGACY_GO:-0}" != "1" ]]; then
    echo "GoWebUI release requires $REQUIRED_GO (Go 1.24+ is required for native Mach-O LC_UUID); got: $(go version)" >&2
    exit 1
  fi
  echo "WARNING: recovery-only legacy Go build enabled ($ACTUAL_GO); LC_UUID will be repaired and verified post-link." >&2
fi
# GoWebUI-RELEASE-LOCK.json freezes every preview/release input.
python3 "$ROOT/scripts/build-gowebui-release-lock.py" --check

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

(
  cd "$ROOT/portable-runtime"
  GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 \
    go build -trimpath -buildvcs=false -ldflags='-s -w' -o "$BIN" .
)
chmod 0755 "$BIN"
if [[ "$ACTUAL_GO" == "$REQUIRED_GO" ]]; then
  python3 "$ROOT/scripts/verify-macho-uuid.py" "$BIN"
else
  python3 "$ROOT/scripts/verify-macho-uuid.py" "$BIN" --repair
fi

ROOT="$ROOT" APP="$APP" VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" python3 - <<'PY'
from pathlib import Path
import os, plistlib, struct

root = Path(os.environ['ROOT'])
app = Path(os.environ['APP'])
version = os.environ['VERSION']
build = os.environ['BUILD_NUMBER']

plist = {
    'CFBundleDevelopmentRegion': 'zh_CN',
    'CFBundleDisplayName': 'MihomoManager',
    'CFBundleExecutable': 'MihomoManager',
    'CFBundleIdentifier': 'cc.kkr.MihomoCoreManager.GoWebUI',
    'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleName': 'MihomoManager',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': version,
    'CFBundleVersion': build,
    'LSApplicationCategoryType': 'public.app-category.utilities',
    'LSMinimumSystemVersion': '14.0',
    'NSHighResolutionCapable': True,
    'NSLocalNetworkUsageDescription': 'MihomoManager 需要访问您配置的局域网 Mihomo Controller、Core 服务面板和 MetaCubeXD。',
    'CFBundleIconFile': 'AppIcon.icns',
    'MCMBuildVariant': 'GoWebUI',
    'NSAppTransportSecurity': {'NSAllowsArbitraryLoads': True},
}
with (app/'Contents/Info.plist').open('wb') as f:
    plistlib.dump(plist, f, sort_keys=False)

# Both GoWebUI and SwiftUI consume this exact AppIcon asset catalog.
icon_dir = root/'MihomoCoreManager/Resources/Assets.xcassets/AppIcon.appiconset'
parts = []
for code, filename in [
    (b'ic10', 'AppIcon-1024.png'),
    (b'ic09', 'AppIcon-512.png'),
    (b'ic08', 'AppIcon-256.png'),
    (b'ic07', 'AppIcon-128.png'),
    (b'icp6', 'AppIcon-64.png'),
    (b'icp5', 'AppIcon-32.png'),
    (b'icp4', 'AppIcon-16.png'),
]:
    data = (icon_dir/filename).read_bytes()
    parts.append(code + struct.pack('>I', 8 + len(data)) + data)
payload = b''.join(parts)
(app/'Contents/Resources/AppIcon.icns').write_bytes(b'icns' + struct.pack('>I', 8 + len(payload)) + payload)
(app/'Contents/Resources/BUILD-VARIANT.txt').write_text(
    f'variant=GoWebUI\nversion={version}\nbuild={build}\n', encoding='utf-8'
)
PY

printf 'GoWebUI app build: PASS\n'
printf '  version: %s (build %s)\n' "$VERSION" "$BUILD_NUMBER"
printf '  output: %s\n' "$APP"
