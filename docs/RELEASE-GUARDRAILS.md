# macOS Release Guardrails

These rules are part of the v1.2.5 release baseline. They were promoted from the
v1.2.4 release incident so later UI work cannot silently reintroduce the same
Xcode failures.

## 1. Treat GitHub macOS Release compilation as a separate compatibility target

A Swift file that only passes `swiftc -frontend -parse` is not proven to compile
under Xcode. The v1.2.4 incident demonstrated that a syntactically valid
`switch Bool?` could still fail Xcode 16.4 exhaustiveness checking.

Rules:

- The Apple Silicon `macos-15` job remains a hard release gate.
- `scripts/release-preflight.py --strict-macos` validates the runner architecture,
  Xcode/Swift toolchain presence, and effective build settings before packaging.
- `scripts/build-release.sh` is the source of truth for the native Release build.

## 2. Keep Optional patterns explicit in release-sensitive Swift code

For `Bool?`, use explicit Optional cases:

```swift
switch value {
case .some(true):
    ...
case .none:
    ...
case .some(false):
    ...
}
```

Do not rewrite this as `case true / nil / false`. The source validator rejects
that regression.

## 3. Keep large SwiftUI result builders small

The proxy page is intentionally decomposed:

- `ProxySortPicker`
- `groupDetailHeader`
- `groupDetailToolbar`
- `groupMemberList`

Do not fold these helpers back into one large `ViewBuilder` expression merely to
reduce line count. Release-mode type checking is more fragile than syntax-only
parsing.

`ProxySortPicker` uses explicit `ProxySortOption` tags, and
`ProxySortOption` remains explicitly `Hashable`.

## 4. Prefer concrete intermediate types over nested Optional expressions

The proxy quality history path intentionally uses a concrete
`[MihomoProxyDelaySample]` value before filtering delays. Avoid restoring
`Array(proxy?.history.suffix(...) ?? [])` in this hot path.

## 5. Keep macOS API usage warning-clean where the minimum OS already supports it

The deployment target is macOS 14. `onChange` uses the macOS 14 two-parameter
closure form. The validator rejects the old one-parameter form in the known
busy-cursor path.

## 6. Preserve compiler diagnostics

Native Release builds must keep:

- `SWIFT_ENABLE_BATCH_MODE=NO`
- `build/xcodebuild-release.log`
- a final `error:` / `fatal error:` diagnostic replay on failure
- CI upload of the Xcode log when the job fails

This prevents another `exit code 65` report with the actionable compiler error
hidden earlier in the log.

## 7. Release simulation is layered

Run:

```bash
bash scripts/simulate-release.sh
```

On any host this performs source gates, source-manifest verification, Swift 5
parsing, `Models.swift` type checking, portable Go tests, a Darwin/arm64 portable
cross-build, ZIP integrity checks, and bundle-version checks.

On an Apple Silicon Mac it additionally runs the strict macOS/Xcode preflight,
the native unsigned Xcode Release build, and SHA-256 verification.

A non-macOS simulation is useful but is not a substitute for the `macos-15`
GitHub Actions hard gate.

## Source-manifest freshness policy

`SOURCE-SHA256SUMS.txt` is generated release metadata. A stale committed
manifest must fail normal CI so source changes cannot silently bypass review.
The Release workflow has a separate rule: immediately after checking out the
exact tag/commit, it regenerates the manifest, verifies it, and emits a warning
when the committed snapshot was stale.

Rules:

- CI / pull requests: `python3 scripts/build-source-manifest.py --check` must pass.
- Before committing source changes: run `python3 scripts/build-source-manifest.py --write`.
- Tagged/manual Release: regenerate once from the exact checkout, then run
  `--check` and the strict macOS/Xcode preflight.
- A stale-manifest failure must identify added, removed, and changed paths.

### Strict preflight must be self-contained

Do not rely only on a preceding GitHub Actions step to refresh generated release
metadata. `release-preflight.py --strict-macos` itself must rebuild and verify
`SOURCE-SHA256SUMS.txt` from the exact checkout before any Xcode/toolchain work.
This specifically prevents historical documentation files such as
`BUILD-FIX-v1.2.4.md` from causing a stale-manifest abort when a workflow is
rerun from a commit whose manifest predates that file.

The non-strict preflight remains read-only and fails on a stale committed
manifest, preserving the development/PR integrity gate.

### Standalone Swift probes must be SDK-bound on macOS

Syntax-only `swiftc -frontend -parse` does not need the macOS SDK. Semantic
`swiftc -typecheck` does. On macOS/Xcode runners, semantic probes must resolve
the SDK with `xcrun --sdk macosx --show-sdk-path`, invoke
`xcrun --sdk macosx swiftc`, pass `-sdk`, and pass the project-compatible target
(`arm64-apple-macos14.0` for v1.2.5). The authoritative full compile remains
`xcodebuild`.
