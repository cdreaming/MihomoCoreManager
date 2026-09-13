# Mihomo Core Manager v1.1.6 QA

## v1.0.9 reference
- Reference installer: v1.0.9 build 109.
- `DashboardActionButtonStyle`: exact source block match with v1.0.9 — PASS.
- Press scale `configuration.isPressed ? 0.985 : 1` — PASS.
- Explicit button press/release animation: none, matching v1.0.9 — PASS.
- Navigation/backend/popover/dismiss: `.plain`, matching v1.0.9 — PASS.
- `MenuBarView.swift`: byte-identical to v1.0.9 — PASS.

## Button audit
- Button declarations inspected: **59**.
- `ContentView.swift`: 5
- `CoreView.swift`: 9
- `LogsView.swift`: 1
- `MenuBarView.swift`: 17
- `OverviewView.swift`: 6
- `SettingsView.swift`: 15
- `SubscriptionsView.swift`: 2
- `UpdateView.swift`: 4

## Regression checks
- Swift parse: **14/14 PASS**.
- Mixed fixed/flexible SwiftUI frame scan: **PASS**.
- Source validator: `source validation: PASS (v1.1.6, arm64, menu/API/settings/release gates)
Spreadsheet runtime warmup failed during python startup
Traceback (most recent call last):
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/patches/warm_spreadsheet_runtime_on_startup.py", line 26, in warm_spreadsheet_runtime_on_startup
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/spreadsheet_warmup.py", line 772, in warm_spreadsheet_runtime
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/rpc/connection.py", line 37, in get_or_create_client
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/rpc/daemon.py", line 124, in start_daemon
TimeoutError: Timed out waiting for artifact tool daemon socket. Set ARTIFACT_TOOL_RPC_DAEMON_STARTUP_TIMEOUT_S=<seconds> to increase the limit.`.
- Source manifest: `source manifest: PASS
Spreadsheet runtime warmup failed during python startup
Traceback (most recent call last):
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/patches/warm_spreadsheet_runtime_on_startup.py", line 26, in warm_spreadsheet_runtime_on_startup
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/spreadsheet_warmup.py", line 785, in warm_spreadsheet_runtime
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/spreadsheet_warmup.py", line 720, in _warm_feature_flows
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/spreadsheet_warmup.py", line 704, in _warm_collaboration_flows
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/generated/interface/models.py", line 32317, in hydrate_crdt_from_proto
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/rpc/remote.py", line 749, in __call__
  File "/tmp/tmp.L2TH2Y5coc/artifact_tool_v2-2.8.22/artifact_tool/rpc/client.py", line 150, in call
artifact_tool.rpc.client.RemoteError: hydrateCrdtFromProto requires an empty collaborative document.`.
- Portable Go tests: `ok  	cc.kkr/MihomoCoreManagerPortable	0.313s`.

## Native build
- Current runtime is not macOS/Xcode, so a genuine rebuilt v1.1.6 `.app/.pkg` cannot be produced here.
- The v1.0.9 installer was used only as a behavior/package reference; its binary was not relabeled as v1.1.6.
