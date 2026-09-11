#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${VERSION//./}"
export GOCACHE="${GOCACHE:-$ROOT/build/go-cache}"

cd "$ROOT"

echo "== v${VERSION} release simulation =="
python3 scripts/release-preflight.py

echo "== portable runtime lifecycle / concurrency stress =="
(
  cd portable-runtime
  export TMPDIR="$ROOT/build/simulated-test-tmp"
  rm -rf "$TMPDIR"
  mkdir -p "$TMPDIR"
  CGO_ENABLED=0 go test -timeout=60s -run '^TestGroupDelayCacheDecoratesSharedProxyData$' -count=100 ./...
  CGO_ENABLED=0 go test -timeout=90s -shuffle=on -count=3 ./...
  if [[ "$(go env GOOS)" == "linux" || "$(go env GOOS)" == "darwin" ]]; then
    CGO_ENABLED=1 go test -race -timeout=120s -count=1 ./...
  fi
  CGO_ENABLED=0 go vet ./...
  GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go test -c -o "$ROOT/build/portable-runtime.test-darwin-arm64" .
)
python3 - "$ROOT/build/portable-runtime.test-darwin-arm64" <<'PYTEST'
from pathlib import Path
import sys
p = Path(sys.argv[1])
data = p.read_bytes()
if data[:4] != bytes.fromhex("cffaedfe"):
    raise SystemExit("darwin/arm64 Go test binary is not 64-bit little-endian Mach-O")
print("darwin/arm64 Go test cross-compile: PASS")
PYTEST

echo "== build portable arm64 release artifact =="
bash scripts/build-portable-installer.sh

PORTABLE="$ROOT/dist-portable/MihomoCoreManager-v${VERSION}-arm64-portable-installer.zip"
[[ -f "$PORTABLE" ]] || { echo "portable ZIP missing: $PORTABLE" >&2; exit 1; }

python3 - "$PORTABLE" "$VERSION" "$BUILD_NUMBER" <<'PY'
from pathlib import Path
import io, plistlib, sys, zipfile

archive = Path(sys.argv[1])
version = sys.argv[2]
build = sys.argv[3]
prefix = f"MihomoCoreManager-v{version}-arm64-portable-installer/"
plist_name = prefix + "MihomoCoreManager.app/Contents/Info.plist"
binary_name = prefix + "MihomoCoreManager.app/Contents/MacOS/MihomoCoreManager"

with zipfile.ZipFile(archive) as zf:
    bad = zf.testzip()
    if bad:
        raise SystemExit(f"portable ZIP CRC failure: {bad}")
    names = set(zf.namelist())
    for name in [plist_name, binary_name, prefix + "Install-MihomoCoreManager.command"]:
        if name not in names:
            raise SystemExit(f"portable ZIP payload missing: {name}")
    plist = plistlib.loads(zf.read(plist_name))
    if plist.get("CFBundleShortVersionString") != version:
        raise SystemExit("portable CFBundleShortVersionString mismatch")
    if plist.get("CFBundleVersion") != build:
        raise SystemExit("portable CFBundleVersion mismatch")
    binary = zf.read(binary_name)
    if binary[:4] != bytes.fromhex("cffaedfe"):
        raise SystemExit("portable executable is not a 64-bit little-endian Mach-O")

print("portable release artifact verification: PASS")
PY

if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
  echo "== native Apple Silicon Xcode release build =="
  python3 scripts/release-preflight.py --strict-macos
  bash scripts/build-release.sh --unsigned

  # Include the portable installer in the same release checksum contract.
  PORTABLE_HASH="$(shasum -a 256 "$PORTABLE" | awk '{print $1}')"
  if ! grep -Fq "  $(basename "$PORTABLE")" dist/SHA256SUMS.txt; then
    printf '%s  %s\n' "$PORTABLE_HASH" "$(basename "$PORTABLE")" >> dist/SHA256SUMS.txt
  fi

  BIN="$ROOT/build/DerivedData/Build/Products/Release/MihomoCoreManager.app/Contents/MacOS/MihomoCoreManager"
  [[ "$(lipo -archs "$BIN" | xargs)" == "arm64" ]] || {
    echo "native app is not arm64-only" >&2
    exit 1
  }

  VERIFY="$ROOT/build/release-simulation-verify"
  rm -rf "$VERIFY"
  mkdir -p "$VERIFY"
  cp dist/* "$VERIFY/"
  cp "$PORTABLE" "$VERIFY/"
  (
    cd "$VERIFY"
    shasum -a 256 -c SHA256SUMS.txt
  )
  echo "native unsigned release simulation: PASS"
else
  echo "native Xcode stage: SKIPPED on $(uname -s)/$(uname -m)"
  echo "The hard gate is .github/workflows/ci.yml on macos-15 arm64 before release."
fi

echo "release simulation: PASS"
