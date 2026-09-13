#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER")"
MODE="${1:---unsigned}"
DIST="${DIST:-$ROOT/dist}"
APP="$ROOT/build/GoWebUI-Release/MihomoCoreManager.app"
BINARY="$APP/Contents/MacOS/MihomoCoreManager"
PKG="$DIST/MihomoCoreManager-v${VERSION}-GoWebUI-arm64.pkg"
MANIFEST="$DIST/GoWebUI-APP-MANIFEST.json"
PROVENANCE="$DIST/GoWebUI-RELEASE-PROVENANCE.txt"

[[ "$(uname -s)" == "Darwin" ]] || { echo "GoWebUI .pkg release requires macOS" >&2; exit 1; }
[[ "$MODE" == "--unsigned" || "$MODE" == "--signed" ]] || { echo "usage: $0 [--unsigned|--signed]" >&2; exit 2; }
mkdir -p "$DIST" "$ROOT/build"
rm -rf "$APP" "$PKG"

# Same canonical builder as ChatGPT-Web portable preview.
bash "$ROOT/scripts/build-gowebui-app.sh" "$APP"

ARCHS="$(lipo -archs "$BINARY" | xargs)"
[[ "$ARCHS" == "arm64" ]] || { echo "GoWebUI binary is not arm64-only: $ARCHS" >&2; exit 1; }

if [[ "$MODE" == "--signed" ]]; then
  : "${DEVELOPER_ID_APPLICATION:?missing Developer ID Application identity}"
  : "${DEVELOPER_ID_INSTALLER:?missing Developer ID Installer identity}"
  : "${NOTARY_KEY_PATH:?missing notary API key path}"
  : "${APPLE_API_KEY_ID:?missing APPLE_API_KEY_ID}"
  : "${APPLE_API_ISSUER_ID:?missing APPLE_API_ISSUER_ID}"

  codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
  productbuild --sign "$DEVELOPER_ID_INSTALLER" --component "$APP" /Applications "$PKG"
  xcrun notarytool submit "$PKG" \
    --key "$NOTARY_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" --wait
  xcrun stapler staple "$PKG"
  xcrun stapler validate "$PKG"
else
  codesign --force --deep --sign - "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
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
cat > "$PROVENANCE" <<EOF
variant=GoWebUI
version=$VERSION
build=$BUILD_NUMBER
source_commit=$SOURCE_COMMIT
architecture=$ARCHS
app_tree_sha256=$TREE_SHA
binary_sha256=$BINARY_SHA
app_builder=scripts/build-gowebui-app.sh
ui_source=portable-runtime/ui/index.html
EOF

printf 'GoWebUI release: PASS\n'
ls -lh "$PKG" "$MANIFEST" "$PROVENANCE"
