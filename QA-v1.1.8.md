# Mihomo Core Manager v1.1.8 QA

## Regression targets

- v1.1.7 busy button lifecycle, spinner, busy cursor and update polling remain unchanged.
- Native success notice waits until the current busy operation exits, then auto-dismisses; error notices remain manual.
- Native sidebar page buttons expose a full-width 47pt hit target and a pronounced pressed animation.
- Portable sidebar page buttons use a full-width 46px minimum hit target and stronger active feedback.
- Settings `task(id:)` uses real profile/section interpolation so the first navigation to Settings loads the current profile without creating another server.
- Logs uses the same corrected persistent-page task ID behavior.

## Build environment

- Swift source syntax parsing, source validation, JavaScript syntax checking and portable Go tests are runnable in this Linux environment.
- The portable arm64 installer can be cross-built here.
- A genuine Xcode SwiftUI `.app/.pkg` still requires Apple Silicon macOS + Xcode; the portable installer is labeled separately and does not masquerade as that artifact.
