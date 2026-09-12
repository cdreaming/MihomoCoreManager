#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${VERSION//./}"
MODE="${1:---unsigned}"
DIST="$ROOT/dist"
DERIVED="$ROOT/build/DerivedData"
BUILT_APP="$DERIVED/Build/Products/Release/MihomoCoreManager.app"
CANONICAL_DIR="$ROOT/build/Canonical"
CANONICAL_APP="$CANONICAL_DIR/MihomoCoreManager.app"
BINARY="$CANONICAL_APP/Contents/MacOS/MihomoCoreManager"
ZIP="$DIST/MihomoCoreManager-v${VERSION}-arm64.zip"
PKG="$DIST/MihomoCoreManager-v${VERSION}-arm64.pkg"
NATIVE_INSTALLER="$DIST/MihomoCoreManager-v${VERSION}-arm64-native-installer.zip"
APP_MANIFEST="$DIST/NATIVE-APP-MANIFEST.json"
PROVENANCE="$DIST/RELEASE-PROVENANCE.txt"
NOTES="$DIST/release_v${VERSION}_notes_zh-CN.md"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
[[ "$MODE" == "--unsigned" || "$MODE" == "--signed" ]] || { echo "usage: $0 [--unsigned|--signed]" >&2; exit 2; }

python3 "$ROOT/scripts/validate-source.py"
rm -rf "$DIST" "$ROOT/build"
mkdir -p "$DIST" "$ROOT/build"

# Release incident guardrails:
# 1) avoid Swift batch compilation for the large SwiftUI target;
# 2) preserve the complete Xcode log and replay compiler diagnostics at the end;
# 3) record the exact macOS/Xcode/Swift toolchain used by the runner.
XCODE_LOG="$ROOT/build/xcodebuild-release.log"
{
  echo "== release toolchain =="
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
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
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
  echo "Full Xcode log: $XCODE_LOG" >&2
  exit "$XCODE_STATUS"
fi

[[ -d "$BUILT_APP" && -x "$BUILT_APP/Contents/MacOS/MihomoCoreManager" ]] || {
  echo "App build missing: $BUILT_APP" >&2
  exit 1
}
BUILT_ARCHS="$(lipo -archs "$BUILT_APP/Contents/MacOS/MihomoCoreManager" | xargs)"
[[ "$BUILT_ARCHS" == "arm64" ]] || { echo "Expected arm64-only binary, got: $BUILT_ARCHS" >&2; exit 1; }

# Sign/notarize the app first. Only after the app is final do we freeze a
# canonical copy. Every public release container is built from that one copy.
if [[ "$MODE" == "--signed" ]]; then
  : "${DEVELOPER_ID_APPLICATION:?missing Developer ID Application identity}"
  : "${DEVELOPER_ID_INSTALLER:?missing Developer ID Installer identity}"
  : "${NOTARY_KEY_PATH:?missing notary API key path}"
  : "${APPLE_API_KEY_ID:?missing APPLE_API_KEY_ID}"
  : "${APPLE_API_ISSUER_ID:?missing APPLE_API_ISSUER_ID}"

  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$BUILT_APP"
  codesign --verify --strict --verbose=2 "$BUILT_APP"

  PRE_NOTARY_ZIP="${RUNNER_TEMP:-$ROOT/build}/MihomoCoreManager-notary.zip"
  rm -f "$PRE_NOTARY_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$BUILT_APP" "$PRE_NOTARY_ZIP"
  xcrun notarytool submit "$PRE_NOTARY_ZIP" \
    --key "$NOTARY_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" --wait
  xcrun stapler staple "$BUILT_APP"
  xcrun stapler validate "$BUILT_APP"
else
  codesign --force --sign - "$BUILT_APP"
  codesign --verify --strict --verbose=2 "$BUILT_APP"
fi

rm -rf "$CANONICAL_DIR"
mkdir -p "$CANONICAL_DIR"
/usr/bin/ditto "$BUILT_APP" "$CANONICAL_APP"
codesign --verify --strict --verbose=2 "$CANONICAL_APP"

ARCHS="$(lipo -archs "$BINARY" | xargs)"
[[ "$ARCHS" == "arm64" ]] || { echo "Frozen canonical app is not arm64-only: $ARCHS" >&2; exit 1; }

# Freeze a content-level manifest before creating any container. UI code,
# assets, Info.plist and signatures are all covered by this manifest.
python3 "$ROOT/scripts/app-bundle-manifest.py" "$CANONICAL_APP" --output "$APP_MANIFEST"

# Public ZIP preview: exact canonical native app.
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$CANONICAL_APP" "$ZIP"

# Public command installer: exact same canonical native app, no rebuild/re-sign.
bash "$ROOT/scripts/package-native-installer.sh" "$CANONICAL_APP" "$DIST"
[[ -f "$NATIVE_INSTALLER" ]] || { echo "native installer missing: $NATIVE_INSTALLER" >&2; exit 1; }

# PKG: package the very same frozen app bundle.
if [[ "$MODE" == "--signed" ]]; then
  productbuild --sign "$DEVELOPER_ID_INSTALLER" --component "$CANONICAL_APP" /Applications "$PKG"
  xcrun notarytool submit "$PKG" \
    --key "$NOTARY_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" --wait
  xcrun stapler staple "$PKG"
  xcrun stapler validate "$PKG"
  pkgutil --check-signature "$PKG"
else
  pkgbuild --component "$CANONICAL_APP" --install-location /Applications "$PKG"
fi

cp "$ROOT/docs/releases/v${VERSION}/RELEASE-NOTES.md" "$NOTES"

SOURCE_COMMIT="${GITHUB_SHA:-}"
if [[ -z "$SOURCE_COMMIT" ]] && command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
  SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
fi
SOURCE_COMMIT="${SOURCE_COMMIT:-unavailable}"
TREE_SHA="$(python3 - "$APP_MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    print(json.load(f)['tree_sha256'])
PY
)"
BINARY_SHA="$(shasum -a 256 "$BINARY" | awk '{print $1}')"
XCODE_VERSION="$(xcodebuild -version | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
SWIFT_VERSION="$(xcrun swiftc --version | head -n 1)"
cat > "$PROVENANCE" <<EOF
version=$VERSION
build=$BUILD_NUMBER
source_commit=$SOURCE_COMMIT
architecture=$ARCHS
app_tree_sha256=$TREE_SHA
binary_sha256=$BINARY_SHA
xcode=$XCODE_VERSION
swift=$SWIFT_VERSION
packaging_contract=one-canonical-native-app
EOF

# Hard parity gate: re-extract every public container and compare the whole app
# bundle file-by-file. A mismatch blocks Release.
bash "$ROOT/scripts/verify-native-release-parity.sh" "$DIST"

(
  cd "$DIST"
  shasum -a 256 \
    "$(basename "$PKG")" \
    "$(basename "$ZIP")" \
    "$(basename "$NATIVE_INSTALLER")" \
    "$(basename "$APP_MANIFEST")" \
    "$(basename "$PROVENANCE")" \
    "$(basename "$NOTES")" \
    > SHA256SUMS.txt
)

printf 'release build: PASS\n'
printf '  App architecture: %s\n' "$ARCHS"
printf '  Canonical app tree SHA-256: %s\n' "$TREE_SHA"
printf '  Packaging contract: one canonical native app -> ZIP / native installer / PKG\n'
ls -lh "$PKG" "$ZIP" "$NATIVE_INSTALLER" "$APP_MANIFEST" "$PROVENANCE" "$NOTES" "$DIST/SHA256SUMS.txt"
