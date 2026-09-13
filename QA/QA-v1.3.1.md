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

## v4.0.1 interface parity / fallback

- [ ] Controller URL accepts deployment `/ui/` or `/Ui/`, strips only the UI suffix and preserves any reverse-proxy prefix and explicit port.
- [ ] Management URL accepts known `/api/...` or `/healthz` endpoints, strips only the known endpoint suffix and preserves reverse-proxy prefix and explicit port.
- [ ] SwiftUI and GoWebUI both use direct HTTP → SSH original URL → SSH `127.0.0.1` same-port fallback for Controller/Management when a LAN SSH route is available.
- [ ] A write request that already received an explicit HTTP status is not replayed against the loopback target.
- [ ] Controller status computes non-zero instantaneous speed from cumulative traffic deltas when traffic changes.
- [ ] systemd logs use `journalctl ... -o short-iso`; Management `/api/logs` remains fallback.
- [ ] Browser-only `/api/login` and `/api/logout` are not required when using Bearer Management Secret; `/healthz` is treated as liveness only.
- [ ] Controller, Management and MetaCubeXD explicit ports are preserved; 9090/29090/29091 are never silently appended.
- [ ] Existing profiles/keychain secrets migrate from the legacy MihomoCoreManager locations after the program rename.

## v4.0.1 interface parity / visible regressions

- [ ] Sidebar `Core 面板` and `MetaCubeXD` versions are populated from Management metadata while `Core 版本` remains Controller-authoritative.
- [ ] Management metadata refresh does not add duplicate traffic samples and is throttled to the slow cadence (30 s).
- [ ] SwiftUI Core page `服务控制` / `服务信息` cards have aligned top edges; no 300pt outer fixed-height overflow remains.
- [ ] Controller `/ui/` and `/Ui/`, `/version`, `/configs` pastes normalize to the API root without dropping reverse-proxy prefixes or explicit ports.
- [ ] Management `/api/status`, `/api/login`, `/api/project-update/*` pastes normalize to the panel root without dropping prefixes or ports.
- [ ] `0.0.0.0` and `::` are rejected as client destinations.
- [ ] No Controller/Management/MetaCubeXD business port is guessed; omitted scheme only infers LAN→HTTP and public→HTTPS.
- [ ] Controller/Management transport fallback is direct HTTP → SSH original URL → SSH loopback same scheme/port/path, and explicit HTTP failures are not replayed as writes.
- [ ] `systemctl reload` runs only when `CanReload=yes`; v4.0.1 default no-ExecReload unit falls through to Management reload.
- [ ] systemd start/restart preserves the v4.0.1 disabled-at-boot policy.
- [ ] MetaCubeXD resolution is LAN explicit → LAN Management + reported port → public/custom URL; no synthetic `:29091`.
- [ ] Controller and Management secrets reuse each other only when their own slot is empty.

## Release

- [ ] Go tests, race/vet where supported, Darwin/arm64 cross-compile and source validation pass.
- [ ] `MihomoManager-v1.3.1-GoWebUI-arm64-portable-installer.zip` installs on Apple Silicon macOS 14+.
- [ ] GitHub Release produces both `MihomoManager-v1.3.1-GoWebUI-arm64.pkg` and `MihomoManager-v1.3.1-SwiftUI-arm64.pkg`.
- [ ] Online Release SHA-256 verification passes.
