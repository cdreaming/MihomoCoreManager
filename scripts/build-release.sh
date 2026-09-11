#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${VERSION//./}"
MODE="${1:---unsigned}"
DIST="$ROOT/dist"
DERIVED="$ROOT/build/DerivedData"
APP="$DERIVED/Build/Products/Release/MihomoCoreManager.app"
BINARY="$APP/Contents/MacOS/MihomoCoreManager"
ZIP="$DIST/MihomoCoreManager-v${VERSION}-arm64.zip"
PKG="$DIST/MihomoCoreManager-v${VERSION}-arm64.pkg"
NOTES="$DIST/release_v${VERSION}_notes_zh-CN.md"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
[[ "$MODE" == "--unsigned" || "$MODE" == "--signed" ]] || { echo "usage: $0 [--unsigned|--signed]" >&2; exit 2; }

python3 "$ROOT/scripts/validate-source.py"
rm -rf "$DIST" "$ROOT/build"
mkdir -p "$DIST" "$ROOT/build"

# v1.2.4 release incident guardrails:
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

[[ -d "$APP" && -x "$BINARY" ]] || { echo "App build missing: $APP" >&2; exit 1; }
ARCHS="$(lipo -archs "$BINARY" | xargs)"
[[ "$ARCHS" == "arm64" ]] || { echo "Expected arm64-only binary, got: $ARCHS" >&2; exit 1; }

if [[ "$MODE" == "--signed" ]]; then
  : "${DEVELOPER_ID_APPLICATION:?missing Developer ID Application identity}"
  : "${DEVELOPER_ID_INSTALLER:?missing Developer ID Installer identity}"
  : "${NOTARY_KEY_PATH:?missing notary API key path}"
  : "${APPLE_API_KEY_ID:?missing APPLE_API_KEY_ID}"
  : "${APPLE_API_ISSUER_ID:?missing APPLE_API_ISSUER_ID}"

  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
  codesign --verify --strict --verbose=2 "$APP"

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
  codesign --force --sign - "$APP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  pkgbuild --component "$APP" --install-location /Applications "$PKG"
fi

cp "$ROOT/docs/releases/v${VERSION}/RELEASE-NOTES.md" "$NOTES"
(
  cd "$DIST"
  shasum -a 256 \
    "$(basename "$PKG")" \
    "$(basename "$ZIP")" \
    "$(basename "$NOTES")" \
    > SHA256SUMS.txt
)

printf 'release build: PASS\n'
printf '  App architecture: %s\n' "$ARCHS"
ls -lh "$PKG" "$ZIP" "$NOTES" "$DIST/SHA256SUMS.txt"
