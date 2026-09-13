#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER")"
MODE="${1:---unsigned}"
DIST="${DIST:-$ROOT/dist}"
DERIVED="$ROOT/build/SwiftUI-DerivedData"
BUILT_APP="$DERIVED/Build/Products/Release/MihomoCoreManager.app"
APP="$ROOT/build/SwiftUI-Release/MihomoCoreManager.app"
BINARY="$APP/Contents/MacOS/MihomoCoreManager"
PKG="$DIST/MihomoCoreManager-v${VERSION}-SwiftUI-arm64.pkg"
MANIFEST="$DIST/SwiftUI-APP-MANIFEST.json"
PROVENANCE="$DIST/SwiftUI-RELEASE-PROVENANCE.txt"
XCODE_LOG="$ROOT/build/xcodebuild-release.log"

[[ "$(uname -s)" == "Darwin" ]] || { echo "SwiftUI .pkg release requires macOS" >&2; exit 1; }
[[ "$MODE" == "--unsigned" || "$MODE" == "--signed" ]] || { echo "usage: $0 [--unsigned|--signed]" >&2; exit 2; }
mkdir -p "$DIST" "$ROOT/build"
rm -rf "$DERIVED" "$APP" "$PKG"

{
  echo "== SwiftUI release toolchain =="
  uname -a
  sw_vers
  xcodebuild -version
  xcrun swiftc --version
  echo "== xcodebuild =="
} | tee "$XCODE_LOG"

set +e
xcodebuild \
  -project "$ROOT/MihomoCoreManager.xcodeproj" \
  -scheme MihomoCoreManager \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_ENABLE_BATCH_MODE=NO \
  clean build 2>&1 | tee -a "$XCODE_LOG"
XCODE_STATUS=${PIPESTATUS[0]}
set -e
if [[ "$XCODE_STATUS" -ne 0 ]]; then
  echo "::group::Xcode compiler diagnostics"
  grep -nE 'error:|fatal error:' "$XCODE_LOG" | tail -n 160 || true
  echo "::endgroup::"
  exit "$XCODE_STATUS"
fi

[[ -d "$BUILT_APP" && -x "$BUILT_APP/Contents/MacOS/MihomoCoreManager" ]] || { echo "SwiftUI app missing" >&2; exit 1; }
mkdir -p "$(dirname "$APP")"
/usr/bin/ditto "$BUILT_APP" "$APP"
ARCHS="$(lipo -archs "$BINARY" | xargs)"
[[ "$ARCHS" == "arm64" ]] || { echo "SwiftUI binary is not arm64-only: $ARCHS" >&2; exit 1; }

if [[ "$MODE" == "--signed" ]]; then
  : "${DEVELOPER_ID_APPLICATION:?missing Developer ID Application identity}"
  : "${DEVELOPER_ID_INSTALLER:?missing Developer ID Installer identity}"
  : "${NOTARY_KEY_PATH:?missing notary API key path}"
  : "${APPLE_API_KEY_ID:?missing APPLE_API_KEY_ID}"
  : "${APPLE_API_ISSUER_ID:?missing APPLE_API_ISSUER_ID}"
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  productbuild --sign "$DEVELOPER_ID_INSTALLER" --component "$APP" /Applications "$PKG"
  xcrun notarytool submit "$PKG" \
    --key "$NOTARY_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" --wait
  xcrun stapler staple "$PKG"
  xcrun stapler validate "$PKG"
else
  codesign --force --sign - "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  pkgbuild --component "$APP" --install-location /Applications "$PKG"
fi

python3 "$ROOT/scripts/app-bundle-manifest.py" "$APP" --output "$MANIFEST"
SOURCE_COMMIT="${GITHUB_SHA:-unavailable}"
if [[ "$SOURCE_COMMIT" == "unavailable" ]] && command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
  SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
fi
TREE_SHA="$(python3 - "$MANIFEST" <<'PY'
import json,sys
with open(sys.argv[1],encoding='utf-8') as f: print(json.load(f)['tree_sha256'])
PY
)"
BINARY_SHA="$(shasum -a 256 "$BINARY" | awk '{print $1}')"
XCODE_VERSION="$(xcodebuild -version | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
SWIFT_VERSION="$(xcrun swiftc --version | head -n 1)"
cat > "$PROVENANCE" <<EOF
variant=SwiftUI
version=$VERSION
build=$BUILD_NUMBER
source_commit=$SOURCE_COMMIT
architecture=$ARCHS
app_tree_sha256=$TREE_SHA
binary_sha256=$BINARY_SHA
xcode=$XCODE_VERSION
swift=$SWIFT_VERSION
ui_source=MihomoCoreManager/*.swift
EOF

printf 'SwiftUI release: PASS\n'
ls -lh "$PKG" "$MANIFEST" "$PROVENANCE"
