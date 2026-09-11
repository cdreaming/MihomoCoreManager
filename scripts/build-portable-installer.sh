#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${VERSION//./}"
DIST="$ROOT/dist-portable"
STAGE="$ROOT/build/portable-installer"
BUNDLE_NAME="MihomoCoreManager.app"
PACKAGE_NAME="MihomoCoreManager-v${VERSION}-arm64-portable-installer"
PACKAGE_DIR="$STAGE/$PACKAGE_NAME"
APP="$PACKAGE_DIR/$BUNDLE_NAME"
BIN="$APP/Contents/MacOS/MihomoCoreManager"
OUT="$DIST/$PACKAGE_NAME.zip"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
command -v go >/dev/null || { echo "Go is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Python 3 is required" >&2; exit 1; }

rm -rf "$STAGE" "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DIST"

(
  cd "$ROOT/portable-runtime"
  GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 \
    go build -trimpath -ldflags='-s -w' -o "$BIN" .
)
chmod 0755 "$BIN"

BIN="$BIN" python3 - <<'PY'
from pathlib import Path
import os, struct
p = Path(os.environ['BIN'])
data = p.read_bytes()[:8]
if len(data) < 8:
    raise SystemExit('portable binary is truncated')
magic, cputype = struct.unpack('<II', data)
if magic != 0xfeedfacf or cputype != 0x0100000c:
    raise SystemExit(f'portable binary is not thin Mach-O arm64: magic=0x{magic:08x} cputype=0x{cputype:08x}')
print('portable Mach-O architecture: arm64')
PY

ROOT="$ROOT" APP="$APP" VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" python3 - <<'PY'
from pathlib import Path
import os, plistlib, struct

root = Path(os.environ['ROOT'])
app = Path(os.environ['APP'])
version = os.environ['VERSION']
build = os.environ['BUILD_NUMBER']

plist = {
    'CFBundleDevelopmentRegion': 'zh_CN',
    'CFBundleDisplayName': 'Mihomo Core Manager',
    'CFBundleExecutable': 'MihomoCoreManager',
    'CFBundleIdentifier': 'cc.kkr.MihomoCoreManager.portable',
    'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleName': 'MihomoCoreManager',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': version,
    'CFBundleVersion': build,
    'LSApplicationCategoryType': 'public.app-category.utilities',
    'LSMinimumSystemVersion': '14.0',
    'NSHighResolutionCapable': True,
    'CFBundleIconFile': 'AppIcon.icns',
    'NSAppTransportSecurity': {'NSAllowsArbitraryLoads': True},
}
with (app/'Contents/Info.plist').open('wb') as f:
    plistlib.dump(plist, f, sort_keys=False)

# Modern icns accepts PNG payloads for these element types.
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
PY

cat > "$PACKAGE_DIR/Install-MihomoCoreManager.command" <<'CMD'
#!/bin/zsh
set -euo pipefail
HERE="${0:A:h}"
SOURCE="$HERE/MihomoCoreManager.app"
TARGET="/Applications/MihomoCoreManager.app"

echo "Mihomo Core Manager installer"
echo "Source: $SOURCE"
echo "Target: $TARGET"

if [[ ! -d "$SOURCE" ]]; then
  echo "Installer payload is incomplete: MihomoCoreManager.app is missing." >&2
  exit 1
fi

/usr/bin/pkill -x MihomoCoreManager >/dev/null 2>&1 || true
if [[ -e "$TARGET" ]]; then
  echo "Replacing existing installation…"
  sudo /bin/rm -rf "$TARGET"
fi

echo "Installing to /Applications…"
sudo /usr/bin/ditto "$SOURCE" "$TARGET"
sudo /usr/bin/codesign --force --deep --sign - "$TARGET" >/dev/null 2>&1 || true

echo "Installation complete."
echo "This portable build is ad-hoc/unsigned and not notarized; macOS may require right-click > Open on first launch."
/usr/bin/open "$TARGET" || true
printf "\nPress any key to close…"
read -k 1
printf "\n"
CMD
chmod 0755 "$PACKAGE_DIR/Install-MihomoCoreManager.command"

cat > "$PACKAGE_DIR/Uninstall-MihomoCoreManager.command" <<'CMD'
#!/bin/zsh
set -euo pipefail
TARGET="/Applications/MihomoCoreManager.app"
/usr/bin/pkill -x MihomoCoreManager >/dev/null 2>&1 || true
if [[ -e "$TARGET" ]]; then
  sudo /bin/rm -rf "$TARGET"
  echo "Removed $TARGET"
else
  echo "MihomoCoreManager.app is not installed in /Applications."
fi
printf "\nPress any key to close…"
read -k 1
printf "\n"
CMD
chmod 0755 "$PACKAGE_DIR/Uninstall-MihomoCoreManager.command"

cat > "$PACKAGE_DIR/README-安装.txt" <<EOF
Mihomo Core Manager v${VERSION} (build ${BUILD_NUMBER}) portable arm64 installer

1. Requires Apple Silicon Mac and macOS 14.0 or later.
2. Double-click Install-MihomoCoreManager.command. It will ask for the administrator password and copy MihomoCoreManager.app to /Applications.
3. This artifact is built from portable-runtime for cross-platform delivery and is not the Xcode SwiftUI release package.
4. It is not Developer ID signed/notarized. If Gatekeeper blocks the first launch, right-click the app in /Applications and choose Open.
5. The official SwiftUI .pkg is produced by scripts/build-release.sh --unsigned on Apple Silicon macOS + Xcode or by the macOS Release GitHub Actions workflow.
EOF

PACKAGE_DIR="$PACKAGE_DIR" OUT="$OUT" python3 - <<'PY'
from pathlib import Path
import os, stat, zipfile
src = Path(os.environ['PACKAGE_DIR'])
out = Path(os.environ['OUT'])
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for path in sorted(src.rglob('*')):
        rel = Path(src.name) / path.relative_to(src)
        if path.is_dir():
            continue
        info = zipfile.ZipInfo.from_file(path, arcname=rel.as_posix())
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = (path.stat().st_mode & 0xFFFF) << 16
        with path.open('rb') as f:
            zf.writestr(info, f.read(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
PY

OUT="$OUT" VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" python3 - <<'PY'
from pathlib import PurePosixPath
import os, plistlib, stat, zipfile
zp = os.environ['OUT']
with zipfile.ZipFile(zp) as z:
    bad = z.testzip()
    if bad:
        raise SystemExit(f'portable ZIP CRC failure: {bad}')
    prefix = f"MihomoCoreManager-v{os.environ['VERSION']}-arm64-portable-installer/MihomoCoreManager.app/Contents/"
    names = set(z.namelist())
    for required in [prefix+'Info.plist', prefix+'MacOS/MihomoCoreManager']:
        if required not in names:
            raise SystemExit(f'portable ZIP missing: {required}')
    p = plistlib.loads(z.read(prefix+'Info.plist'))
    got = (str(p.get('CFBundleShortVersionString', '')), str(p.get('CFBundleVersion', '')))
    expected = (os.environ['VERSION'], os.environ['BUILD_NUMBER'])
    if got != expected:
        raise SystemExit(f'portable ZIP bundle version mismatch: got {got}, expected {expected}')
print('portable ZIP integrity: PASS')
PY

if command -v shasum >/dev/null 2>&1; then
  printf '%s  %s\n' "$(shasum -a 256 "$OUT" | awk '{print $1}')" "$(basename "$OUT")" > "$OUT.sha256"
else
  python3 - "$OUT" <<'PY'
from pathlib import Path
import hashlib, sys
p = Path(sys.argv[1])
d = hashlib.sha256(p.read_bytes()).hexdigest()
Path(str(p)+'.sha256').write_text(f"{d}  {p.name}\n")
PY
fi

file "$BIN" || true
ls -lh "$OUT" "$OUT.sha256"
echo "portable installer build: PASS"
