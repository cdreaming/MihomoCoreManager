# Mihomo Core Manager v1.1.7 QA

## Button lifecycle

- Exact active operation tracking: static gate added.
- Project update waits for remote `running` completion: static gate added.
- Management-panel restart/transient disconnect keeps update busy: static gate added.
- Native busy label uses `ProgressView`: static gate added.
- Native busy cursor animator follows active-button hover and Reduce Motion: static gate added.
- Native press scale `0.955` with spring/downshift/shadow: static gate added.
- Portable busy class + `aria-busy` + `cursor: progress`: Go regression test added.
- Portable press scale `0.945` + active flash/inset shadow: Go regression test added.

## Build environment

- Source validation and portable Go tests can run in this Linux environment.
- A genuine SwiftUI `.app/.pkg` rebuild still requires Apple Silicon macOS + Xcode; no existing binary is relabeled as v1.1.7.
