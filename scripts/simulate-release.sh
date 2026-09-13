#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER")"
export GOCACHE="${GOCACHE:-$ROOT/build/go-cache}"

cd "$ROOT"
echo "== v${VERSION} (build ${BUILD_NUMBER}) dual release simulation =="

MANIFEST_BEFORE="$ROOT/build/source-manifest.before"
mkdir -p "$ROOT/build"
if [[ -f SOURCE-SHA256SUMS.txt ]]; then cp SOURCE-SHA256SUMS.txt "$MANIFEST_BEFORE"; else : > "$MANIFEST_BEFORE"; fi
python3 scripts/build-source-manifest.py --write
python3 scripts/build-source-manifest.py --check
if ! cmp -s "$MANIFEST_BEFORE" SOURCE-SHA256SUMS.txt; then
  echo "WARNING: committed SOURCE-SHA256SUMS.txt was stale; refreshed from this exact checkout." >&2
fi

python3 scripts/release-preflight.py
python3 scripts/release_host_policy.py --self-test

echo "== GoWebUI runtime lifecycle / concurrency stress =="
(
  cd portable-runtime
  export TMPDIR="$ROOT/build/simulated-test-tmp"
  rm -rf "$TMPDIR" && mkdir -p "$TMPDIR"
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
p=Path(sys.argv[1]); data=p.read_bytes()
if data[:4] != bytes.fromhex('cffaedfe'):
    raise SystemExit('darwin/arm64 Go test binary is not 64-bit little-endian Mach-O')
print('darwin/arm64 Go test cross-compile: PASS')
PYTEST

echo "== build GoWebUI portable preview from the shared app builder =="
bash scripts/build-portable-installer.sh
PORTABLE="$ROOT/dist-portable/MihomoManager-v${VERSION}-GoWebUI-arm64-portable-installer.zip"
[[ -f "$PORTABLE" ]] || { echo "GoWebUI portable ZIP missing: $PORTABLE" >&2; exit 1; }

python3 - "$PORTABLE" "$VERSION" "$BUILD_NUMBER" <<'PY'
from pathlib import Path
import plistlib,sys,zipfile
archive=Path(sys.argv[1]); version=sys.argv[2]; build=sys.argv[3]
prefix=f'MihomoManager-v{version}-GoWebUI-arm64-portable-installer/'
plist_name=prefix+'MihomoManager.app/Contents/Info.plist'
binary_name=prefix+'MihomoManager.app/Contents/MacOS/MihomoManager'
with zipfile.ZipFile(archive) as zf:
    bad=zf.testzip()
    if bad: raise SystemExit(f'portable ZIP CRC failure: {bad}')
    names=set(zf.namelist())
    for n in [plist_name,binary_name,prefix+'Install-MihomoManager.command']:
        if n not in names: raise SystemExit(f'portable payload missing: {n}')
    pl=plistlib.loads(zf.read(plist_name))
    assert pl['CFBundleShortVersionString']==version
    assert pl['CFBundleVersion']==build
    assert pl['MCMBuildVariant']=='GoWebUI'
    assert zf.read(binary_name)[:4]==bytes.fromhex('cffaedfe')
print('GoWebUI portable preview verification: PASS')
PY

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "== macOS host -> arm64 dual .pkg release =="
  echo "host=$(uname -m); target=arm64"
  python3 scripts/release-preflight.py --strict-macos
  bash scripts/build-release.sh --unsigned
  test -f "dist/MihomoManager-v${VERSION}-GoWebUI-arm64.pkg"
  test -f "dist/MihomoManager-v${VERSION}-SwiftUI-arm64.pkg"
  (
    cd dist
    shasum -a 256 -c SHA256SUMS.txt
  )
  echo "dual unsigned .pkg release simulation: PASS"
else
  echo "GitHub dual .pkg stage: SKIPPED on $(uname -s)/$(uname -m)"
  echo "CI/Release runs this stage on macos-15-intel and cross-builds arm64-only artifacts."
fi

echo "release simulation: PASS"
