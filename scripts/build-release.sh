#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${VERSION//./}"
MODE="${1:---unsigned}"
DIST="$ROOT/dist"
DERIVED="$ROOT/build/DerivedData"
XCODE_LOG="$ROOT/build/xcodebuild-release.log"
APP="$DERIVED/Build/Products/Release/MihomoCoreManager.app"
BINARY="$APP/Contents/MacOS/MihomoCoreManager"
ZIP="$DIST/MihomoCoreManager-v${VERSION}-arm64.zip"
PKG="$DIST/MihomoCoreManager-v${VERSION}-arm64.pkg"
NOTES="$DIST/release_v${VERSION}_notes_zh-CN.md"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
[[ "$MODE" == "--unsigned" || "$MODE" == "--signed" ]] || { echo "usage: $0 [--unsigned|--signed]" >&2; exit 2; }
command -v xcodebuild >/dev/null || { echo "Xcode/xcodebuild is required" >&2; exit 1; }
command -v lipo >/dev/null || { echo "lipo is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

python3 "$ROOT/scripts/validate-source.py"
rm -rf "$DIST" "$ROOT/build"
mkdir -p "$DIST" "$ROOT/build"

XCODE_ARGS=(
  -project "$ROOT/MihomoCoreManager.xcodeproj"
  -scheme MihomoCoreManager
  -configuration Release
  -destination 'generic/platform=macOS'
  -derivedDataPath "$DERIVED"
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
  MACOSX_DEPLOYMENT_TARGET=14.0
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
  SWIFT_ENABLE_BATCH_MODE=NO
  CODE_SIGNING_ALLOWED=NO
  clean build
)

echo "+ xcodebuild ${XCODE_ARGS[*]}"
set +e
xcodebuild "${XCODE_ARGS[@]}" 2>&1 | tee "$XCODE_LOG"
XCODE_STATUS=${PIPESTATUS[0]}
set -e
if (( XCODE_STATUS != 0 )); then
  echo "xcodebuild failed with exit code $XCODE_STATUS" >&2
  echo "---- compiler diagnostics ----" >&2
  grep -nE '(^|[[:space:]])(error:|fatal error:)|SwiftCompile|CompileSwift|BUILD FAILED' "$XCODE_LOG" | tail -n 160 >&2 || true
  echo "---- log tail ----" >&2
  tail -n 120 "$XCODE_LOG" >&2 || true
  exit "$XCODE_STATUS"
fi

[[ -d "$APP" && -x "$BINARY" ]] || { echo "App build missing: $APP" >&2; exit 1; }
ARCHS="$(lipo -archs "$BINARY" | xargs)"
[[ "$ARCHS" == "arm64" ]] || { echo "Expected arm64-only binary, got: $ARCHS" >&2; exit 1; }

APP="$APP" VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" python3 - <<'PY'
import os, plistlib
from pathlib import Path
app = Path(os.environ['APP'])
with (app/'Contents/Info.plist').open('rb') as f:
    p = plistlib.load(f)
expected = (os.environ['VERSION'], os.environ['BUILD_NUMBER'])
got = (str(p.get('CFBundleShortVersionString', '')), str(p.get('CFBundleVersion', '')))
if got != expected:
    raise SystemExit(f'Built app version mismatch: got {got}, expected {expected}')
print(f'built bundle version: {got[0]} ({got[1]})')
PY

if [[ "$MODE" == "--signed" ]]; then
  : "${DEVELOPER_ID_APPLICATION:?missing Developer ID Application identity}"
  : "${DEVELOPER_ID_INSTALLER:?missing Developer ID Installer identity}"
  : "${NOTARY_KEY_PATH:?missing notary API key path}"
  : "${APPLE_API_KEY_ID:?missing APPLE_API_KEY_ID}"
  : "${APPLE_API_ISSUER_ID:?missing APPLE_API_ISSUER_ID}"

  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"

  PRE_NOTARY_ZIP="${RUNNER_TEMP:-$ROOT/build}/MihomoCoreManager-notary.zip"
  rm -f "$PRE_NOTARY_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$PRE_NOTARY_ZIP"
  xcrun notarytool submit "$PRE_NOTARY_ZIP" \
    --key "$NOTARY_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"

  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  productbuild --sign "$DEVELOPER_ID_INSTALLER" --component "$APP" /Applications "$PKG"
  xcrun notarytool submit "$PKG" \
    --key "$NOTARY_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" --wait
  xcrun stapler staple "$PKG"
  xcrun stapler validate "$PKG"
  pkgutil --check-signature "$PKG"
else
  codesign --force --deep --sign - "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  pkgbuild --component "$APP" --install-location /Applications "$PKG"
  pkgutil --payload-files "$PKG" >/dev/null
fi

ZIP="$ZIP" VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" python3 - <<'PY'
import os, plistlib, zipfile
from pathlib import PurePosixPath
zp = os.environ['ZIP']
with zipfile.ZipFile(zp) as z:
    bad = z.testzip()
    if bad:
        raise SystemExit(f'ZIP CRC failure: {bad}')
    names = z.namelist()
    prefix = 'MihomoCoreManager.app/Contents/'
    if prefix+'Info.plist' not in names or prefix+'MacOS/MihomoCoreManager' not in names:
        raise SystemExit('release ZIP is missing app bundle essentials')
    p = plistlib.loads(z.read(prefix+'Info.plist'))
    got = (str(p.get('CFBundleShortVersionString', '')), str(p.get('CFBundleVersion', '')))
    expected = (os.environ['VERSION'], os.environ['BUILD_NUMBER'])
    if got != expected:
        raise SystemExit(f'ZIP bundle version mismatch: got {got}, expected {expected}')
print('release ZIP integrity: PASS')
PY

cp "$ROOT/docs/releases/v${VERSION}/RELEASE-NOTES.md" "$NOTES"
(
  cd "$DIST"
  shasum -a 256 \
    "$(basename "$PKG")" \
    "$(basename "$ZIP")" \
    "$(basename "$NOTES")" \
    > SHA256SUMS.txt
  shasum -a 256 -c SHA256SUMS.txt
)

printf 'release build: PASS\n'
printf '  App architecture: %s\n' "$ARCHS"
printf '  xcodebuild log: %s\n' "$XCODE_LOG"
ls -lh "$PKG" "$ZIP" "$NOTES" "$DIST/SHA256SUMS.txt"
