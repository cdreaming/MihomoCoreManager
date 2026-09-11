#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${VERSION//./}"
STRICT_MACOS=0

for arg in "$@"; do
  case "$arg" in
    --strict-macos) STRICT_MACOS=1 ;;
    *) echo "usage: $0 [--strict-macos]" >&2; exit 2 ;;
  esac
done

cd "$ROOT"
mkdir -p build/release-simulation

echo "release simulation: v${VERSION} (build ${BUILD_NUMBER})"
echo "host: $(uname -s) $(uname -m)"
echo "python: $(python3 --version 2>&1)"
echo "go: $(go version 2>&1)"

if (( STRICT_MACOS )); then
  python3 scripts/release-preflight.py --strict-macos
else
  python3 scripts/release-preflight.py
fi

echo "== Go deterministic/regression gates =="
(
  cd portable-runtime
  CGO_ENABLED=0 go test ./...
  CGO_ENABLED=0 go test -run '^TestGroupDelayCacheDecoratesSharedProxyData$' -count=300 ./...
  CGO_ENABLED=0 go test -shuffle=on -count=10 ./...
  go vet ./...
  CGO_ENABLED=1 go test -race ./...
)

echo "== Darwin arm64 Go compile gate =="
(
  cd portable-runtime
  CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go test -c -o "$ROOT/build/release-simulation/MihomoCoreManagerPortable-tests-darwin-arm64" .
)
python3 - <<'PY'
from pathlib import Path
import struct
p = Path('build/release-simulation/MihomoCoreManagerPortable-tests-darwin-arm64')
data = p.read_bytes()[:8]
if len(data) < 8:
    raise SystemExit('Darwin arm64 Go test binary is truncated')
magic, cpu = struct.unpack('<II', data)
if magic != 0xfeedfacf or cpu != 0x0100000c:
    raise SystemExit(f'Darwin Go test binary is not thin Mach-O arm64: magic=0x{magic:08x} cpu=0x{cpu:08x}')
print('Darwin Go test binary: Mach-O arm64 PASS')
PY

echo "== Portable release artifact =="
bash scripts/build-portable-installer.sh
PORTABLE="dist-portable/MihomoCoreManager-v${VERSION}-arm64-portable-installer.zip"
[[ -f "$PORTABLE" && -f "$PORTABLE.sha256" ]] || { echo "portable artifacts missing" >&2; exit 1; }
if command -v shasum >/dev/null 2>&1; then
  (cd dist-portable && shasum -a 256 -c "$(basename "$PORTABLE").sha256")
else
  python3 - "$PORTABLE" "$PORTABLE.sha256" <<'PY'
from pathlib import Path
import hashlib, sys
p=Path(sys.argv[1]); checksum=Path(sys.argv[2]).read_text().split()[0]
actual=hashlib.sha256(p.read_bytes()).hexdigest()
if actual != checksum: raise SystemExit(f'portable SHA mismatch: {actual} != {checksum}')
print('portable SHA-256: PASS')
PY
fi

if (( STRICT_MACOS )); then
  echo "== Native Xcode Release build =="
  bash scripts/build-release.sh --unsigned

  BIN="build/DerivedData/Build/Products/Release/MihomoCoreManager.app/Contents/MacOS/MihomoCoreManager"
  [[ "$(lipo -archs "$BIN" | xargs)" == "arm64" ]] || { echo "native app binary is not arm64-only" >&2; exit 1; }

  PORTABLE_HASH="$(shasum -a 256 "$PORTABLE" | awk '{print $1}')"
  if ! grep -Fq "  $(basename "$PORTABLE")" dist/SHA256SUMS.txt; then
    printf '%s  %s\n' "$PORTABLE_HASH" "$(basename "$PORTABLE")" >> dist/SHA256SUMS.txt
  fi
  # GitHub Release assets are flat, so SHA256SUMS includes the portable ZIP.
  # Mirror that flat layout briefly for the pre-upload checksum replay.
  cp "$PORTABLE" "dist/$(basename "$PORTABLE")"
  (
    cd dist
    shasum -a 256 -c SHA256SUMS.txt
  )
  rm -f "dist/$(basename "$PORTABLE")"

  python3 - <<'PY'
from pathlib import Path
import os, plistlib, zipfile
version=Path('VERSION').read_text().strip(); build=version.replace('.','')
expected={
    f'MihomoCoreManager-v{version}-arm64.pkg',
    f'MihomoCoreManager-v{version}-arm64.zip',
    f'release_v{version}_notes_zh-CN.md',
    'SHA256SUMS.txt',
}
actual={p.name for p in Path('dist').iterdir() if p.is_file()}
missing=expected-actual
if missing: raise SystemExit(f'native dist missing: {sorted(missing)}')
portable=Path(f'dist-portable/MihomoCoreManager-v{version}-arm64-portable-installer.zip')
if not portable.is_file(): raise SystemExit('portable release ZIP missing')
print('strict macOS release artifacts: PASS')
PY
else
  echo "note: native Xcode .app/.pkg build skipped because this host is not an Apple Silicon macOS/Xcode runner."
fi

echo "release simulation: PASS"
