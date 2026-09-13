# v1.3.1 networking hotfix (version unchanged)

This patch intentionally keeps **v1.3.1 / build 1301**.

- Main-window brand logo now uses a dedicated transparent asset instead of the macOS application-icon rendering path. GoWebUI uses transparent `<img>` elements with no logo plate/shadow.
- Mihomo **Controller URL is the primary Core connection**. Management URL is optional and reserved for lifecycle, subscription writes, system logs and project update features.
- A pasted Controller URL ending in `/ui/` is normalized to the API root. Example: `http://192.168.9.202:9090/ui/` → `http://192.168.9.202:9090`.
- Ports are **not auto-added**. Explicit non-default ports such as `:9090`, `:29090` or `:29091` must remain in the URL unless a reverse proxy exposes the service on 80/443.
- Status/liveness prefers the direct Controller (`/version`, plus `/connections` when available) and only falls back to the optional management endpoint for legacy profiles.
- Settings copy and layout now separate “Mihomo Core connection” from “optional management”, reducing the previous Server/Core ambiguity.
