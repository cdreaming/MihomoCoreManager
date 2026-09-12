#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER")"
MODE="${1:---unsigned}"
DIST="$ROOT/dist"
NOTES="$DIST/release_v${VERSION}_notes_zh-CN.md"
VARIANTS="$DIST/BUILD-VARIANTS.txt"
LOCK_ASSET="$DIST/GoWebUI-RELEASE-LOCK.json"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid BUILD_NUMBER: $BUILD_NUMBER" >&2; exit 1; }
[[ "$MODE" == "--unsigned" || "$MODE" == "--signed" ]] || { echo "usage: $0 [--unsigned|--signed]" >&2; exit 2; }

python3 "$ROOT/scripts/validate-source.py"
rm -rf "$DIST"
mkdir -p "$DIST" "$ROOT/build"

# v1.3.0 dual-release contract:
# - GoWebUI official .pkg is built from the same build-gowebui-app.sh used by
#   the ChatGPT-Web portable preview.
# - SwiftUI is built independently with Xcode and is explicitly named SwiftUI.
# The two implementations intentionally coexist instead of pretending to be the
# same UI binary.
DIST="$DIST" bash "$ROOT/scripts/build-gowebui-release.sh" "$MODE"
DIST="$DIST" bash "$ROOT/scripts/build-swiftui-release.sh" "$MODE"

cp "$ROOT/docs/releases/v${VERSION}/RELEASE-NOTES.md" "$NOTES"
cp "$ROOT/GoWebUI-RELEASE-LOCK.json" "$LOCK_ASSET"
cat > "$VARIANTS" <<EOF
Mihomo Core Manager v${VERSION} (build ${BUILD_NUMBER})

Official GitHub Release variants:
- GoWebUI: Go + AppKit/JXA + WKWebView/Web UI
  Package: MihomoCoreManager-v${VERSION}-GoWebUI-arm64.pkg
  Quick preview: MihomoCoreManager-v${VERSION}-GoWebUI-arm64-portable-installer.zip
  Canonical builder shared by preview and .pkg: scripts/build-gowebui-app.sh

- SwiftUI: SwiftUI + AppKit native implementation
  Package: MihomoCoreManager-v${VERSION}-SwiftUI-arm64.pkg

Both variants share VERSION, BUILD_NUMBER, release notes and AppIcon assets.
They are separate UI implementations and are named accordingly.
EOF

(
  cd "$DIST"
  shasum -a 256 \
    "MihomoCoreManager-v${VERSION}-GoWebUI-arm64.pkg" \
    "MihomoCoreManager-v${VERSION}-SwiftUI-arm64.pkg" \
    "GoWebUI-APP-MANIFEST.json" \
    "SwiftUI-APP-MANIFEST.json" \
    "GoWebUI-RELEASE-PROVENANCE.txt" \
    "SwiftUI-RELEASE-PROVENANCE.txt" \
    "$(basename "$NOTES")" \
    "$(basename "$VARIANTS")" \
    "$(basename "$LOCK_ASSET")" \
    > SHA256SUMS.txt
)

echo "dual implementation release build: PASS"
ls -lh "$DIST"/*
