#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISHER="$ROOT/scripts/github-release.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mcm-gh-release-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

make_fixture() {
  scenario="$1"
  case_dir="$TMP/$scenario"
  mkdir -p "$case_dir/bin" "$case_dir/work/dist" "$case_dir/work/docs/releases/v1.3.1"
  printf 'release notes\n' > "$case_dir/work/docs/releases/v1.3.1/RELEASE-NOTES.md"
  printf 'asset-a\n' > "$case_dir/work/dist/a.pkg"
  printf 'asset-b\n' > "$case_dir/work/dist/b.txt"
  : > "$case_dir/log"
  : > "$case_dir/state"

  cat > "$case_dir/bin/gh" <<'FAKEGH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCENARIO="${FAKE_GH_SCENARIO:?}"
LOG="${FAKE_GH_LOG:?}"
STATE="${FAKE_GH_STATE:?}"
printf '%s\n' "$*" >> "$LOG"
count() {
  key="$1"
  current="$(grep -E "^${key}=" "$STATE" 2>/dev/null | tail -1 | cut -d= -f2 || true)"
  case "$current" in ''|*[!0-9]*) current=0 ;; esac
  current=$((current + 1))
  tmp="${STATE}.tmp"
  grep -Ev "^${key}=" "$STATE" 2>/dev/null > "$tmp" || true
  printf '%s=%s\n' "$key" "$current" >> "$tmp"
  mv "$tmp" "$STATE"
  printf '%s\n' "$current"
}

if [ "${1:-}" = "api" ]; then
  n="$(count api)"
  case "$SCENARIO" in
    existing|upload-transient)
      exit 0
      ;;
    missing)
      echo 'gh: Not Found (HTTP 404)' >&2
      exit 1
      ;;
    probe500-then-missing)
      if [ "$n" -eq 1 ]; then
        echo 'gh: Internal Server Error (HTTP 500)' >&2
        exit 1
      fi
      echo 'gh: Not Found (HTTP 404)' >&2
      exit 1
      ;;
    create-ambiguous)
      created="$(grep -E '^created=' "$STATE" 2>/dev/null | tail -1 | cut -d= -f2 || true)"
      if [ "$created" = "1" ]; then exit 0; fi
      echo 'gh: Not Found (HTTP 404)' >&2
      exit 1
      ;;
  esac
fi

if [ "${1:-}" = "release" ] && [ "${2:-}" = "create" ]; then
  n="$(count create)"
  if [ "$SCENARIO" = "create-ambiguous" ] && [ "$n" -eq 1 ]; then
    printf 'created=1\n' >> "$STATE"
    echo 'HTTP 500 after server-side create' >&2
    exit 1
  fi
  exit 0
fi

if [ "${1:-}" = "release" ] && [ "${2:-}" = "edit" ]; then
  count edit >/dev/null
  exit 0
fi

if [ "${1:-}" = "release" ] && [ "${2:-}" = "upload" ]; then
  n="$(count upload)"
  if [ "$SCENARIO" = "upload-transient" ] && [ "$n" -eq 1 ]; then
    echo 'gh: Service Unavailable (HTTP 503)' >&2
    exit 1
  fi
  exit 0
fi

if [ "${1:-}" = "release" ] && [ "${2:-}" = "download" ]; then
  exit 0
fi

echo "unexpected fake gh invocation: $*" >&2
exit 9
FAKEGH
  chmod +x "$case_dir/bin/gh"
}

run_case() {
  scenario="$1"
  make_fixture "$scenario"
  case_dir="$TMP/$scenario"
  (
    cd "$case_dir/work"
    PATH="$case_dir/bin:$PATH" \
    FAKE_GH_SCENARIO="$scenario" \
    FAKE_GH_LOG="$case_dir/log" \
    FAKE_GH_STATE="$case_dir/state" \
    GH_RETRY_DISABLE_SLEEP=1 \
    GH_RETRY_MAX_ATTEMPTS=5 \
    TAG=v1.3.1 VERSION=1.3.1 \
      bash "$PUBLISHER" publish
  )
  echo "release publisher test: PASS ($scenario)"
}

run_case existing
run_case missing
run_case probe500-then-missing
run_case create-ambiguous
run_case upload-transient

# Critical regression gate: a 500 probe must not immediately trigger create.
LOG="$TMP/probe500-then-missing/log"
first_api="$(grep -n '^api ' "$LOG" | sed -n '1p' | cut -d: -f1)"
second_api="$(grep -n '^api ' "$LOG" | sed -n '2p' | cut -d: -f1)"
first_create="$(grep -n '^release create ' "$LOG" | sed -n '1p' | cut -d: -f1)"
[ -n "$first_api" ] && [ -n "$second_api" ] && [ -n "$first_create" ]
[ "$first_api" -lt "$second_api" ] && [ "$second_api" -lt "$first_create" ] || {
  echo "HTTP 500 regression: create happened before a confirmed 404" >&2
  cat "$LOG" >&2
  exit 1
}

# Ambiguous create must probe and recover instead of blindly creating again.
create_count="$(grep -c '^release create ' "$TMP/create-ambiguous/log" || true)"
[ "$create_count" -eq 1 ] || {
  echo "ambiguous-create regression: expected exactly one create, got $create_count" >&2
  cat "$TMP/create-ambiguous/log" >&2
  exit 1
}

echo "github release retry/idempotency tests: PASS"
