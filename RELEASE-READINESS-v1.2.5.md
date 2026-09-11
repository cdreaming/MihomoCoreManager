# v1.2.5 Release Readiness

## Incident carry-forward audit

The supplied v1.2.5 source had reintroduced several release fixes that were
already required by the v1.2.4 macOS/Xcode incident:

- `ProxySortOption` no longer explicitly conformed to `Hashable`.
- The isolated `ProxySortPicker` had been folded back into `ProxiesView`.
- The proxy-group detail UI had been folded back into one large SwiftUI result builder.
- The quality-history expression had returned to a nested Optional/slice expression.
- `switch proxy?.alive` had returned to `case true / nil / false`, the pattern
  rejected by Xcode 16.4 in the v1.2.4 Release build.
- The busy-cursor `onChange` had returned to the deprecated one-parameter form.
- `SWIFT_ENABLE_BATCH_MODE=NO` and the persistent Xcode diagnostic log had been
  removed from `scripts/build-release.sh`.
- The source validator no longer guarded any of the above release fixes.

All of those release fixes are restored in this v1.2.5 package, while retaining
the intended v1.2.5 status-menu and title-bar changes.

## Permanent guardrails added in v1.2.5

- `scripts/validate-source.py` rejects every known v1.2.4 compile regression.
- `scripts/release-preflight.py` validates source/manifests, Xcode project source
  membership, Swift 5 parsing, `Models.swift` type checking, Go tests, and the
  known Xcode 16.4 regression signatures.
- `scripts/release-preflight.py --strict-macos` additionally requires Apple
  Silicon macOS, checks the Xcode/Swift toolchain, and validates effective
  Release build settings.
- `scripts/simulate-release.sh` performs the portable Darwin/arm64 cross-build,
  ZIP integrity checks, and bundle-version checks. On Apple Silicon macOS it
  also executes the native unsigned Xcode Release build and SHA-256 verification.
- CI and Release workflows run the strict macOS preflight before packaging.
- Failed Xcode builds upload `build/xcodebuild-release.log`.
- The rules are documented in `docs/RELEASE-GUARDRAILS.md`.

## Simulation performed while preparing this package

Preparation host:

- Linux x86_64
- Swift 6.2.1, parsing in Swift 5 language mode
- Go 1.23.2
- Python 3.13.5

Passed:

- source validation
- source manifest verification
- shell syntax checks for release/build scripts
- all 14 Swift source files parsed in Swift 5 language mode
- `Models.swift` semantic type check
- portable `CGO_ENABLED=0 go test ./...`
- portable `GOOS=darwin GOARCH=arm64 CGO_ENABLED=0` build
- portable executable identified as Mach-O 64-bit arm64
- portable ZIP CRC/integrity verification
- portable bundle version `1.2.5` / build `125`

## Native Xcode boundary

This preparation environment is not macOS and therefore cannot execute
Apple's Xcode/AppKit/SwiftUI toolchain. It would be misleading to claim that a
Linux parse is identical to a native Xcode Release build.

The package therefore makes the real Apple Silicon `macos-15` Xcode build a
hard gate in both CI and Release. A GitHub Release is only created after that
native build, packaging, portable build, architecture check, and checksum stages
succeed.

The v1.2.4 failure pattern is now explicitly rejected before the Xcode build, so
the known Xcode 16.4 regression cannot silently return.

## Manifest-preflight follow-up

A release attempt failed before Xcode because the committed
`SOURCE-SHA256SUMS.txt` did not match the tagged checkout. Release now refreshes
that generated metadata before `release-preflight.py --strict-macos`. Normal CI
continues to enforce a committed fresh manifest.

## Strict-preflight self-heal follow-up

A real macOS arm64 run showed that relying on a separate workflow refresh step
was insufficient: `BUILD-FIX-v1.2.4.md` existed in the checkout but was absent
from the committed source manifest. `release-preflight.py --strict-macos` now
refreshes the manifest itself before checking it. The historical v1.2.4 fix note
is also included in this source bundle and therefore represented in the
regenerated manifest.
