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

## Release

- [ ] Go tests, race/vet where supported, Darwin/arm64 cross-compile and source validation pass.
- [ ] `MihomoCoreManager-v1.3.1-GoWebUI-arm64-portable-installer.zip` installs on Apple Silicon macOS 14+.
- [ ] GitHub Release produces both `MihomoCoreManager-v1.3.1-GoWebUI-arm64.pkg` and `MihomoCoreManager-v1.3.1-SwiftUI-arm64.pkg`.
- [ ] Online Release SHA-256 verification passes.
