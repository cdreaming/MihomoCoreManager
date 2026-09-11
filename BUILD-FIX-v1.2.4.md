# v1.2.4 macOS CI compile fix

The GitHub Actions `Apple Silicon arm64 build` failed in the Release Swift
compile phase (`ContentView.swift`, exit code 65). The captured screenshot only
contained the final `SwiftCompile` failure summary, not the earlier compiler
diagnostic, so this patch removes the fragile type-checking path and makes any
future diagnostic visible at the end of the CI step.

Fixed:

- Isolated the proxy sort segmented `Picker` into a small `ProxySortPicker` view
  with explicit `ProxySortOption` tags.
- Split the proxy-group detail ViewBuilder into smaller functions to reduce
  Release-mode SwiftUI type-checker pressure.
- Rewrote quality-history extraction with explicit concrete types instead of a
  nested optional/slice expression.
- Made `ProxySortOption` explicitly `Hashable`.
- Disabled Swift batch compilation for the release build
  (`SWIFT_ENABLE_BATCH_MODE=NO`) so failures are isolated to one file.
- Tee the full `xcodebuild` output to `build/xcodebuild-release.log` and print
  compiler `error:` lines again at the end of a failed GitHub Actions step.

Validated in the repair environment:

- `python3 scripts/validate-source.py`
- `python3 scripts/build-source-manifest.py --check`
- every Swift source passes `swiftc -frontend -parse -swift-version 5`
- `CGO_ENABLED=0 go test ./...`
- portable arm64 installer build produces a Mach-O arm64 executable

The final native `xcodebuild` still has to run on a macOS/Xcode runner.
## Follow-up: Xcode 16.4 Optional<Bool> exhaustiveness

The next macOS 15 / Xcode 16.4 run exposed the actual compiler error at `ContentView.swift:1219`: `switch proxy?.alive` used `case true`, `case nil`, and `case false`. Xcode 16.4 does not treat those expression-pattern cases as exhaustive for `Bool?`. The switch now uses `.some(true)`, `.none`, and `.some(false)`. The macOS 14 `onChange` deprecation warning shown in the same log is also updated to the two-argument closure form.
