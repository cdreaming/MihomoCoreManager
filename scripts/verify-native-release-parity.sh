#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${VERSION//./}"
DIST="${1:-$ROOT/dist}"
APP_ZIP="$DIST/MihomoManager-v${VERSION}-arm64.zip"
PKG="$DIST/MihomoManager-v${VERSION}-arm64.pkg"
INSTALLER="$DIST/MihomoManager-v${VERSION}-arm64-native-installer.zip"
EXPECTED_MANIFEST="$DIST/NATIVE-APP-MANIFEST.json"

[[ "$(uname -s)" == "Darwin" ]] || { echo "native release parity verification requires macOS" >&2; exit 1; }
for tool in ditto pkgutil lipo python3; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done
for file in "$APP_ZIP" "$PKG" "$INSTALLER" "$EXPECTED_MANIFEST"; do
  [[ -f "$file" ]] || { echo "release parity input missing: $file" >&2; exit 1; }
done

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mcm-parity.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/appzip" "$TMP/installer"

/usr/bin/ditto -x -k "$APP_ZIP" "$TMP/appzip"
/usr/bin/ditto -x -k "$INSTALLER" "$TMP/installer"
/usr/sbin/pkgutil --expand-full "$PKG" "$TMP/pkg"

find_app() {
  local root="$1"
  local found
  found="$(find "$root" -type d -name 'MihomoManager.app' -print | head -n 1)"
  [[ -n "$found" ]] || { echo "MihomoManager.app not found under $root" >&2; exit 1; }
  printf '%s\n' "$found"
}

ZIP_APP="$(find_app "$TMP/appzip")"
INSTALLER_APP="$(find_app "$TMP/installer")"
PKG_APP="$(find_app "$TMP/pkg")"

python3 "$ROOT/scripts/app-bundle-manifest.py" "$ZIP_APP" --output "$TMP/appzip-manifest.json"
python3 "$ROOT/scripts/app-bundle-manifest.py" "$INSTALLER_APP" --output "$TMP/installer-manifest.json"
python3 "$ROOT/scripts/app-bundle-manifest.py" "$PKG_APP" --output "$TMP/pkg-manifest.json"

cmp -s "$EXPECTED_MANIFEST" "$TMP/appzip-manifest.json" || {
  echo "native app ZIP does not match NATIVE-APP-MANIFEST.json" >&2
  diff -u "$EXPECTED_MANIFEST" "$TMP/appzip-manifest.json" | head -n 120 >&2 || true
  exit 1
}
cmp -s "$TMP/appzip-manifest.json" "$TMP/installer-manifest.json" || {
  echo "native installer ZIP contains a different app bundle" >&2
  diff -u "$TMP/appzip-manifest.json" "$TMP/installer-manifest.json" | head -n 120 >&2 || true
  exit 1
}
cmp -s "$TMP/appzip-manifest.json" "$TMP/pkg-manifest.json" || {
  echo "PKG contains a different app bundle" >&2
  diff -u "$TMP/appzip-manifest.json" "$TMP/pkg-manifest.json" | head -n 120 >&2 || true
  exit 1
}

python3 - "$ZIP_APP" "$VERSION" "$BUILD_NUMBER" <<'PY'
from pathlib import Path
import plistlib, sys
app = Path(sys.argv[1])
version, build = sys.argv[2], sys.argv[3]
with (app/'Contents/Info.plist').open('rb') as f:
    plist = plistlib.load(f)
if plist.get('CFBundleShortVersionString') != version:
    raise SystemExit(f"CFBundleShortVersionString mismatch: {plist.get('CFBundleShortVersionString')} != {version}")
if plist.get('CFBundleVersion') != build:
    raise SystemExit(f"CFBundleVersion mismatch: {plist.get('CFBundleVersion')} != {build}")
print(f"bundle version: PASS (v{version} / build {build})")
PY

for app in "$ZIP_APP" "$INSTALLER_APP" "$PKG_APP"; do
  archs="$(/usr/bin/lipo -archs "$app/Contents/MacOS/MihomoManager" | xargs)"
  [[ "$archs" == "arm64" ]] || { echo "expected arm64-only app, got: $archs ($app)" >&2; exit 1; }
  /usr/bin/codesign --verify --strict --verbose=1 "$app" >/dev/null 2>&1 || {
    echo "codesign verification failed for extracted app: $app" >&2
    exit 1
  }
done

TREE_SHA="$(python3 - "$EXPECTED_MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    print(json.load(f)['tree_sha256'])
PY
)"
printf 'native release parity: PASS\n'
printf '  app tree SHA-256: %s\n' "$TREE_SHA"
printf '  identical bundle in: app ZIP / native installer ZIP / PKG\n'
