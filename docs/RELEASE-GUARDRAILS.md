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
