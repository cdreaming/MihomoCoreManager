#!/usr/bin/env bash
set -Eeuo pipefail

# Hardened GitHub Release publisher/downloader.
# Designed for GitHub Actions' macOS bash as well as modern bash.
# Important invariant: a failed release probe is NOT automatically treated as 404.

MAX_ATTEMPTS="${GH_RETRY_MAX_ATTEMPTS:-6}"
BASE_DELAY="${GH_RETRY_BASE_SECONDS:-3}"
MAX_DELAY="${GH_RETRY_MAX_SECONDS:-30}"
DISABLE_SLEEP="${GH_RETRY_DISABLE_SLEEP:-0}"

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

for value_name in MAX_ATTEMPTS BASE_DELAY MAX_DELAY; do
  eval "value=\${$value_name}"
  if ! is_uint "$value"; then
    echo "$value_name must be a non-negative integer (got: $value)" >&2
    exit 2
  fi
done
if [ "$MAX_ATTEMPTS" -lt 1 ]; then
  echo "GH_RETRY_MAX_ATTEMPTS must be >= 1" >&2
  exit 2
fi

retry_delay_for_attempt() {
  attempt="$1"
  delay="$BASE_DELAY"
  i=1
  while [ "$i" -lt "$attempt" ]; do
    delay=$((delay * 2))
    if [ "$delay" -ge "$MAX_DELAY" ]; then
      delay="$MAX_DELAY"
      break
    fi
    i=$((i + 1))
  done
  printf '%s\n' "$delay"
}

sleep_before_retry() {
  attempt="$1"
  reason="$2"
  delay="$(retry_delay_for_attempt "$attempt")"
  echo "::warning::${reason}; retry ${attempt}/${MAX_ATTEMPTS} after ${delay}s"
  if [ "$DISABLE_SLEEP" != "1" ] && [ "$delay" -gt 0 ]; then
    sleep "$delay"
  fi
}

retry_command() {
  description="$1"
  shift
  attempt=1
  while :; do
    if "$@"; then
      return 0
    else
      rc=$?
    fi
    if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
      echo "::error::${description} failed after ${MAX_ATTEMPTS} attempts (exit=${rc})" >&2
      return "$rc"
    fi
    sleep_before_retry "$attempt" "$description failed (exit=${rc})"
    attempt=$((attempt + 1))
  done
}

# Return codes:
#   0  release exists
#   44 release definitely does not exist (HTTP 404)
#   75 transient/unknown GitHub API failure; MUST NOT be treated as 404
probe_release_once() {
  output=""
  if output="$(gh api "repos/{owner}/{repo}/releases/tags/${TAG}" --silent 2>&1)"; then
    return 0
  else
    rc=$?
  fi

  # Keep the original GitHub diagnostic visible in Actions logs.
  if [ -n "$output" ]; then
    printf '%s\n' "$output" >&2
  fi

  case "$output" in
    *"HTTP 404"*|*"(HTTP 404)"*|*"404 Not Found"*|*"Not Found (404)"*)
      return 44
      ;;
  esac

  echo "GitHub release probe failed without a confirmed 404 (gh exit=${rc}); treating as transient/unknown." >&2
  return 75
}

ensure_release() {
  attempt=1
  while :; do
    if probe_release_once; then
      echo "Release ${TAG} already exists; refreshing title and notes."
      retry_command "gh release edit ${TAG}" \
        gh release edit "$TAG" --notes-file "$NOTES" --title "$TAG"
      return 0
    else
      probe_rc=$?
    fi

    if [ "$probe_rc" -eq 44 ]; then
      echo "Release ${TAG} is confirmed absent (HTTP 404); creating it."
      if gh release create "$TAG" --verify-tag --title "$TAG" --notes-file "$NOTES"; then
        return 0
      else
        create_rc=$?
      fi

      # Creation is not safely retryable without checking first: GitHub may have
      # committed the release even if the client received a 5xx/network failure.
      echo "::warning::gh release create ${TAG} returned exit=${create_rc}; probing before any retry"
    else
      echo "::warning::Release probe for ${TAG} was transient/unknown; will NOT call create until a real 404 is observed"
    fi

    if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
      echo "::error::Unable to ensure GitHub Release ${TAG} after ${MAX_ATTEMPTS} attempts" >&2
      return 1
    fi
    sleep_before_retry "$attempt" "ensure release ${TAG} not complete"
    attempt=$((attempt + 1))
  done
}

collect_assets() {
  shopt -s nullglob
  ASSETS=("$DIST_DIR"/*)
  shopt -u nullglob
  if [ "${#ASSETS[@]}" -eq 0 ]; then
    echo "No release assets found in ${DIST_DIR}/" >&2
    return 1
  fi
}

publish_release() {
  : "${TAG:?TAG is required}"
  : "${VERSION:?VERSION is required}"
  NOTES="${NOTES:-docs/releases/v${VERSION}/RELEASE-NOTES.md}"
  DIST_DIR="${DIST_DIR:-dist}"

  command -v gh >/dev/null 2>&1 || { echo "gh CLI is required" >&2; exit 127; }
  [ -f "$NOTES" ] || { echo "Release notes not found: $NOTES" >&2; exit 2; }
  [ -d "$DIST_DIR" ] || { echo "Release asset directory not found: $DIST_DIR" >&2; exit 2; }
  collect_assets

  ensure_release

  # Upload one asset at a time so a transient failure only retries that asset.
  # --clobber is intentionally retained for re-runs; retrying restores an asset
  # if GitHub deleted the old copy before an upload failed.
  for asset in "${ASSETS[@]}"; do
    name="$(basename "$asset")"
    retry_command "upload release asset ${name}" \
      gh release upload "$TAG" "$asset" --clobber
  done

  echo "GitHub Release publish: PASS (${TAG}, ${#ASSETS[@]} assets)"
}

download_release() {
  : "${TAG:?TAG is required}"
  destination="${1:-${VERIFY_DIR:-}}"
  [ -n "$destination" ] || { echo "download destination is required" >&2; exit 2; }
  command -v gh >/dev/null 2>&1 || { echo "gh CLI is required" >&2; exit 127; }
  mkdir -p "$destination"
  retry_command "download release assets for ${TAG}" \
    gh release download "$TAG" -D "$destination" --clobber
  echo "GitHub Release download: PASS (${TAG})"
}

usage() {
  cat >&2 <<'USAGE'
Usage:
  TAG=v1.3.1 VERSION=1.3.1 bash scripts/github-release.sh publish
  TAG=v1.3.1 bash scripts/github-release.sh download <directory>

Optional retry controls:
  GH_RETRY_MAX_ATTEMPTS=6
  GH_RETRY_BASE_SECONDS=3
  GH_RETRY_MAX_SECONDS=30
USAGE
  exit 2
}

case "${1:-}" in
  publish) publish_release ;;
  download) shift; download_release "${1:-}" ;;
  *) usage ;;
esac
