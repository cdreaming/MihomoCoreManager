#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${VERSION//./}"
APP="${1:-$ROOT/build/Canonical/MihomoCoreManager.app}"
DIST="${2:-$ROOT/dist}"
STAGE="$ROOT/build/native-installer"
PACKAGE_NAME="MihomoCoreManager-v${VERSION}-arm64-native-installer"
PACKAGE_DIR="$STAGE/$PACKAGE_NAME"
OUT="$DIST/$PACKAGE_NAME.zip"

[[ "$(uname -s)" == "Darwin" ]] || { echo "native installer packaging requires macOS" >&2; exit 1; }
[[ -d "$APP" ]] || { echo "canonical app missing: $APP" >&2; exit 1; }
command -v ditto >/dev/null || { echo "ditto is required" >&2; exit 1; }

rm -rf "$STAGE"
mkdir -p "$PACKAGE_DIR" "$DIST"
/usr/bin/ditto "$APP" "$PACKAGE_DIR/MihomoCoreManager.app"

cat > "$PACKAGE_DIR/Install-MihomoCoreManager.command" <<'CMD'
#!/bin/zsh
set -euo pipefail
HERE="${0:A:h}"
SOURCE="$HERE/MihomoCoreManager.app"
TARGET="/Applications/MihomoCoreManager.app"

echo "Mihomo Core Manager native installer"
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

echo "Installing the exact native app bundle used by the GitHub .pkg…"
sudo /usr/bin/ditto "$SOURCE" "$TARGET"

echo "Installation complete."
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
Mihomo Core Manager v${VERSION} (build ${BUILD_NUMBER}) native installer

This archive contains the exact same Xcode-built MihomoCoreManager.app bundle that is packaged into:
  MihomoCoreManager-v${VERSION}-arm64.pkg

The GitHub Release workflow verifies the app bundle file-by-file with SHA-256 after extracting both artifacts. If they differ, the release fails.

1. Requires Apple Silicon Mac and macOS 14.0 or later.
2. Double-click Install-MihomoCoreManager.command to copy the bundled native app to /Applications.
3. The installer does NOT rebuild or re-sign the app. It copies the frozen canonical app bundle byte-for-byte.
EOF

rm -f "$OUT"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$OUT"
ls -lh "$OUT"
echo "native installer packaging: PASS"
