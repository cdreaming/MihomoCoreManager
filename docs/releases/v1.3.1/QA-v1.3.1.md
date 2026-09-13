# QA v1.3.1

## Shared release inputs

- [ ] `VERSION` = `1.3.1`.
- [ ] `BUILD_NUMBER` = `1301`.
- [ ] Xcode `MARKETING_VERSION=1.3.1`, `CURRENT_PROJECT_VERSION=1301`.
- [ ] GoWebUI runtime reports `1.3.1 / 1301`.
- [ ] `GoWebUI-RELEASE-LOCK.json` passes `python3 scripts/build-gowebui-release-lock.py --check`.
- [ ] Go toolchain is exactly `go1.23.2` for release builds.

## Layout / naming / icon

- [ ] SwiftUI right pane starts at or below the highest left sidebar content line; all primary pages use the shared 38pt top inset.
- [ ] GoWebUI macOS shell right pane uses 38px top padding and does not override it back to 26px.
- [ ] Navigation Tab and page header display `服务设置` in both implementations.
- [ ] `branding/MihomoCoreManager-2.png` is retained as the uploaded source icon.
- [ ] Dock/Finder, SwiftUI sidebar/overview, GoWebUI sidebar/overview use the generated shared icon.
- [ ] Icon assets are present at 16, 32, 64, 128, 256, 512 and 1024 px.

## GoWebUI LAN backend

- [ ] `http://127.0.0.1`, RFC1918 private IP and link-local targets bypass inherited HTTP(S) proxies.
- [ ] Single-label LAN host, `.local`, `.lan` and `.home.arpa` names are treated as explicit local destinations.
- [ ] On macOS CGO=0, a resolvable Bonjour/local hostname can use the system resolver fallback and connect.
- [ ] Public HTTPS backends continue to honor normal system/environment proxy behavior.
- [ ] `允许不安全 HTTP` remains required for explicit `http://` profiles.

## Cloudflare Tunnel

- [ ] Management/Controller 502/503/504/52x/530 read failures retry only with bounded backoff; writes are not blindly retried.
- [ ] Cloudflare 530 / Error 1033 shows the concise Tunnel-unreachable message.
- [ ] GoWebUI clears idle connections after transient tunnel/network errors and backs off repeated failed status/proxy polling.
- [ ] SwiftUI status polling backs off after repeated failures and recovers to the configured normal interval after success.
- [ ] A short Tunnel interruption does not immediately erase the last successful proxy snapshot.

## v4.0.1 interface parity / visible regressions

- [ ] Sidebar panel/XD versions come from Management metadata without overriding Controller Core version.
- [ ] Core service cards align at top and no fixed 300pt frame remains.
- [ ] `/ui/` / `/Ui/` and known API suffixes normalize while preserving explicit ports and reverse-proxy prefixes.
- [ ] Wildcard listeners `0.0.0.0` / `::` are rejected as client destinations.
- [ ] Reload checks `CanReload`; no-ExecReload systemd falls through to Management.
- [ ] MetaCubeXD prefers LAN Management host + reported port before public URL and never guesses 29091.
- [ ] Controller/Management Secret fallback is symmetric.

## Release

- [ ] Go tests, race/vet where supported, Darwin/arm64 cross-compile and source validation pass.
- [ ] `MihomoManager-v1.3.1-GoWebUI-arm64-portable-installer.zip` installs on Apple Silicon macOS 14+.
- [ ] GitHub Release produces both `MihomoManager-v1.3.1-GoWebUI-arm64.pkg` and `MihomoManager-v1.3.1-SwiftUI-arm64.pkg`.
- [ ] Online Release SHA-256 verification passes.
- [ ] `bash scripts/test-github-release.sh` passes all 5xx/404/create-ambiguity/upload retry scenarios.
- [ ] A `gh api`/release probe HTTP 500 never causes `gh release create` until a confirmed HTTP 404 is observed.
- [ ] A create command that returns failure after server-side creation is recovered by probe/edit without a second blind create.
- [ ] `Retry Existing GitHub Release` can rebuild/publish an existing tag without moving that tag.
- [ ] Release diagnostics are uploaded for failures in create/upload/online verification stages.
