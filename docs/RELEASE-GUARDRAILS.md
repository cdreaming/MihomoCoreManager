# macOS Release Guardrails

These rules were proven by the successful v1.2.5 release baseline and are mandatory for v1.2.7. They were promoted from the
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

`SOURCE-SHA256SUMS.txt` is generated release metadata. The v1.2.7 failure showed
that keeping the refresh only in one workflow is not enough: CI can enter the
canonical simulation with historical documentation present in the checkout but
missing from the committed manifest. That aborts before Swift/Xcode/Go tests.

Rules:

- Before committing source changes, still run `python3 scripts/build-source-manifest.py --write`.
- `scripts/simulate-release.sh` always rebuilds the manifest from the exact
  checkout, immediately verifies it, and prints a warning if the committed copy
  was stale. CI and Release both use this same entry point.
- Direct non-strict `release-preflight.py` remains read-only and can still be
  used by developers to detect an unrefreshed committed manifest.
- `release-preflight.py --strict-macos` also retains its own write/check safety
  net before Xcode work, so it is safe when invoked directly.
- A stale-manifest diagnostic must identify added, removed, and changed paths.

This policy preserves the manifest as useful release metadata without allowing a
generated checksum file to prevent the real compiler and runtime gates from
running. Historical files such as `BUILD-FIX-v1.2.4.md`, `QA-v1.2.6.md`, and
`RELEASE-HARDENING-v1.2.6.md` are included in the final v1.2.7 source manifest.

### Standalone Swift probes must be SDK-bound on macOS

Syntax-only `swiftc -frontend -parse` does not need the macOS SDK. Semantic
`swiftc -typecheck` does. On macOS/Xcode runners, semantic probes must resolve
the SDK with `xcrun --sdk macosx --show-sdk-path`, invoke
`xcrun --sdk macosx swiftc`, pass `-sdk`, and pass the project-compatible target
(`arm64-apple-macos14.0` for v1.2.7). The authoritative full compile remains
`xcodebuild`.

### Background work must be owned and quiesced in tests

Request handlers may trigger cache refreshes asynchronously, but those goroutines
must be registered through `appState.goBackground`. Tests that use a temporary
state directory must register `state.waitBackground` with `t.Cleanup` before the
temporary directory is removed. This prevents macOS/APFS cleanup races where a
background refresh recreates `Runtime/` while `testing.TempDir` is deleting it.

Release parity for the portable runtime now includes the exact regression test
repeated on the macOS runner, a shuffled multi-run suite, Go's race detector,
`go vet`, and a darwin/arm64 cross-compile of both runtime and test binary.

### One canonical real-runner release simulation

CI and Release must not maintain separate hand-written sequences of partial
checks. Both invoke `bash scripts/simulate-release.sh` on the same `macos-15`
Apple Silicon runner used for publishing. That script owns the portable runtime
stress/race suite, darwin/arm64 cross-compiles, portable installer verification,
strict Xcode preflight, native unsigned Xcode build, architecture check, and
checksum replay. A release is uploaded only after this complete script passes.
