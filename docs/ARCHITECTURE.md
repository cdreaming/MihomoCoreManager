# macOS App 架构

```text
┌──────────────────────────── Apple Silicon macOS ────────────────────────────┐
│ MihomoManager.app                                                      │
│                                                                            │
│  SwiftUI Window                  MenuBarExtra                              │
│  ┌───────────────┐              ┌────────────────────────┐                 │
│  │ Overview/Core │              │ Status / Core actions  │                 │
│  │ Subs/Logs/Upd │              │ Subs/Logs/Update links │                 │
│  └───────┬───────┘              └────────────┬───────────┘                 │
│          └──────────────────┬────────────────┘                             │
│                             v                                              │
│                    @MainActor AppModel                                     │
│               ┌──────────────┴──────────────┐                              │
│               v                             v                              │
│      ProfileStore (JSON)            KeychainStore (Secret)                │
│               │                             │                              │
│               └──────────────┬──────────────┘                              │
│                              v                                             │
│                    MihomoAPIClient / URLSession                            │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │ HTTPS / opt-in HTTP
          ┌────────────────────┴────────────────────┐
          v                                         v
Mihomo Core 管理面板 v4.0.0                  Optional direct Controller
/api/status, /api/action, ...                /configs?force=true
          │                                         │
          └────────────────────┬────────────────────┘
                               v
                         Mihomo Core
```

## 为什么无需服务端 CORS 改造

v4.0.0 浏览器 UI 需要同源策略和 CORS 管理；macOS 原生 `URLSession` 不是浏览器，因此不会执行浏览器 CORS 检查。服务端 POST 的 `_same_origin()` 在没有 `Origin` header 时允许请求，而 `_authorized()` 已支持 Bearer Core Secret，刚好适合原生客户端。

## 配置路径的语义

当服务器 Profile 填写了 Direct Core Controller URL 时，“重载配置”使用该 URL，并把 Profile 中的 `config.yaml path` 作为 Mihomo `/configs?force=true` 的 `path` 发送。Direct Controller 留空时，App 调用管理面板 `POST /api/action {"action":"reload"}`，此时实际配置路径由远端面板自身的 `MIHOMO_CONFIG` 决定。

这种设计既让配置文件路径真正可由 App 设置，又保持对原始 v4.0.0 服务端的零改造兼容。
