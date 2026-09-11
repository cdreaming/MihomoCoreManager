#!/usr/bin/env python3
from pathlib import Path
import plistlib, re, sys

root = Path(__file__).resolve().parents[1]
errors = []
version = (root / "VERSION").read_text(encoding="utf-8").strip()
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    errors.append(f"VERSION invalid: {version!r}")

required = [
    "MihomoCoreManager.xcodeproj/project.pbxproj",
    "MihomoCoreManager/MihomoCoreManagerApp.swift",
    "MihomoCoreManager/API/MihomoAPIClient.swift",
    "MihomoCoreManager/Views/MenuBarView.swift",
    "MihomoCoreManager/Views/SettingsView.swift",
    ".github/workflows/release.yml",
    ".github/workflows/ci.yml",
    "SOURCE-SHA256SUMS.txt",
    "scripts/build-portable-installer.sh",
    "scripts/release-preflight.py",
    "scripts/simulate-release.sh",
    "docs/RELEASE-GUARDRAILS.md",
]
for rel in required:
    if not (root / rel).is_file(): errors.append(f"missing: {rel}")

pbx = (root / "MihomoCoreManager.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
if "ARCHS = arm64;" not in pbx: errors.append("Xcode project is not arm64-only")
if "MACOSX_DEPLOYMENT_TARGET = 14.0;" not in pbx: errors.append("deployment target must be macOS 14.0")
if f"MARKETING_VERSION = {version};" not in pbx: errors.append(f"Xcode MARKETING_VERSION must match VERSION {version}")
expected_build = version.replace(".", "")
if f"CURRENT_PROJECT_VERSION = {expected_build};" not in pbx: errors.append(f"Xcode build number must be {expected_build}")
if not (root / f"docs/releases/v{version}/RELEASE-NOTES.md").is_file(): errors.append(f"release notes missing for v{version}")
portable = root / "portable-runtime/main.go"
if portable.is_file() and not re.search(rf'appVersion\s*=\s*\"{re.escape(version)}\"', portable.read_text(encoding="utf-8")):
    errors.append("portable runtime appVersion must match VERSION")

client = (root / "MihomoCoreManager/API/MihomoAPIClient.swift").read_text(encoding="utf-8")
for endpoint in ["/api/status", "/api/action", "/api/subscriptions", "/api/logs", "/api/project-update/check", "/api/project-update/apply", "/api/project-update/log"]:
    if endpoint not in client: errors.append(f"missing API endpoint: {endpoint}")
for marker in ["/configs", "/proxies", "proxyMode", "setProxyMode", "selectProxy", "ControllerProxiesResponse"]:
    if marker not in client:
        errors.append(f"native v1.2.3 proxy API gate missing: {marker}")
for marker in ["/group", "proxyGroupOrder", "testProxyGroup", "makeControllerNamedURL", "testUrl", "expectedStatus"]:
    if marker not in client:
        errors.append(f"native v1.2.4 proxy delay/order API gate missing: {marker}")
for marker in ["extra: [String: MihomoProxyDelayExtra]?", "JSONSerialization.jsonObject", "number.intValue"]:
    if marker not in client:
        errors.append(f"native v1.2.4 latency hotfix gate missing: {marker}")
for marker in ["/providers/proxies", "ControllerProvidersResponse", "ControllerProviderWire", "provider.proxies", "merged[name] == nil"]:
    if marker not in client:
        errors.append(f"native v1.2.4 provider-leaf latency gate missing: {marker}")
for marker in ["isTransientControllerStatus", "Cloudflare Tunnel 暂时断开", "Error 1033", "maxAttempts", "Task.sleep"]:
    if marker not in client:
        errors.append(f"native v1.2.4 Cloudflare retry gate missing: {marker}")
models_auth = (root / "MihomoCoreManager/Models.swift").read_text(encoding="utf-8")
settings_auth = (root / "MihomoCoreManager/Views/SettingsView.swift").read_text(encoding="utf-8")
for marker in ["controllerUnauthorized", 'if !secret.isEmpty', "Controller Secret"]:
    if marker not in client + "\n" + models_auth + "\n" + settings_auth:
        errors.append(f"native v1.2.3 controller auth-fix gate missing: {marker}")
if 'Authorization' not in client or 'Bearer' not in client: errors.append("Bearer authentication missing")
if '.convertToSnakeCase' not in client: errors.append("JSON POST encoding must preserve v4 snake_case keys")
for marker in ["shouldRetrySubscriptionApplyWithRestart", "热重载超时", "action(.stop", "action(.start", "operationFailed"]:
    if marker not in client + "\n" + (root / "MihomoCoreManager/Models.swift").read_text(encoding="utf-8"):
        errors.append(f"native subscription timeout recovery missing: {marker}")

menu = (root / "MihomoCoreManager/Views/MenuBarView.swift").read_text(encoding="utf-8")
for marker in ["图标", "状态", "网速", "仅图标", "启动", "停止", "重启", "重载配置", "应用订阅 + 热重载", "订阅管理…", "运行日志…", "检查项目更新", "开始项目升级", "MetaCubeXD", "设置…"]:
    if marker not in menu: errors.append(f"menu function missing: {marker}")
for marker in ["proxyMenus", "代理组", "测速此组", "proxyGroupsInDefaultOrder", "effectiveProxyDelay", "selectProxy"]:
    if marker not in menu:
        errors.append(f"native v1.2.4 status-bar proxy-menu gate missing: {marker}")
for marker in ["menuProxyTitle(proxyName, group: group)", "preferredTestURL: group.testURL"]:
    if marker not in menu:
        errors.append(f"native v1.2.4 tray latency hotfix gate missing: {marker}")
if 'Image(systemName: "point.3.connected.trianglepath.dotted")' in menu:
    errors.append("native v1.2.4 hotfix must not add a synthetic symbol before proxy-group names")

settings = (root / "MihomoCoreManager/Views/SettingsView.swift").read_text(encoding="utf-8")
for marker in ["Management URL", "Core Secret", "Controller Secret", "Direct Core Controller URL", "config.yaml path", "MetaCubeXD URL", "允许不安全 HTTP"]:
    if marker not in settings: errors.append(f"settings field missing: {marker}")
if "NSPasteboard.general.string" not in settings or "doc.on.clipboard" not in settings:
    errors.append("Core Secret explicit paste support missing from native settings")

portable_ui = (root / "portable-runtime/ui/index.html").read_text(encoding="utf-8")
portable_main = (root / "portable-runtime/main.go").read_text(encoding="utf-8")
for marker in ["pasteSecret", "/local/clipboard", "支持 ⌘V"]:
    if marker not in portable_ui + "\n" + portable_main:
        errors.append(f"portable paste support missing: {marker}")
for marker in ["'粘贴','paste:','v'", "'复制','copy:','c'", "'全选','selectAll:','a'"]:
    if marker not in portable_main:
        errors.append(f"portable standard Edit menu missing: {marker}")
for marker in ["Mihomo Core 管理面板", "实时流量", "快速控制", "brand-mark", "trafficChart"]:
    if marker not in portable_ui:
        errors.append(f"v4 dashboard UI marker missing: {marker}")
for marker in ['data-nav="proxies"', 'data-view="proxies"', "规则", "全局", "直连", "proxyGroups", "switchProxy"]:
    if marker not in portable_ui:
        errors.append(f"portable v1.2.3 proxy UI gate missing: {marker}")
for marker in ["/local/proxy-mode", "/local/proxies", "/local/proxy-select", "handleProxyMode", "handleProxies", "handleProxySelect", "joinProxyURL"]:
    if marker not in portable_main:
        errors.append(f"portable v1.2.3 proxy API gate missing: {marker}")
for marker in ["controllerKeychainService", "controllerSecretFor", "ControllerSecret", "/local/controller-secret/clear"]:
    if marker not in portable_main:
        errors.append(f"portable v1.2.3 controller auth-fix gate missing: {marker}")
for marker in ["pControllerSecret", "pasteControllerSecret", "clearControllerSecret"]:
    if marker not in portable_ui:
        errors.append(f"portable v1.2.3 controller-secret UI gate missing: {marker}")
for marker in ["data-group-sort", "data-proxy-sort", "setGroupSort", "setProxySort", "compareQualityNames", "测速当前组", "/local/proxy-delay", "lastTestDelay"]:
    if marker not in portable_ui:
        errors.append(f"portable v1.2.4 proxy sort/delay UI gate missing: {marker}")
for marker in ["proxyData?.GLOBAL?.all", "Object.values(p.extra)", "lastTestDelay=value", "proxyData[resolved].lastTestDelay=value", "latencyFromSamples", "extraHistory", "value.history", "resolvedProxyName", "latencyItem", "v>0"]:
    if marker not in portable_ui:
        errors.append(f"portable v1.2.4 order/latency hotfix UI gate missing: {marker}")
for marker in ["if(data._stale)", "if(!data._stale)", "Controller 暂时不可达，正在显示最近一次代理数据", "if(proxyData?.[group])proxyData[group].now=name"]:
    if marker not in portable_ui:
        errors.append(f"portable v1.2.4 Cloudflare stale-data UI gate missing: {marker}")
if "groups=await api('/local/proxy-groups')" in portable_ui:
    errors.append("portable v1.2.4 default order must not depend on /group map iteration")
for marker in ["/local/proxy-groups", "/local/proxy-delay", "handleProxyGroups", "handleProxyDelay", "proxyDelayCache", "joinGroupDelayURL", "lastTestDelay", "rebuildProxyMenus", "测速此组", "selectProxyMenu"]:
    if marker not in portable_main:
        errors.append(f"portable v1.2.4 proxy delay/status-menu gate missing: {marker}")
for marker in [
    "decorateProxyPayload",
    "latencyFromProxyObject",
    "latencyFromExtraValue",
    "mergeProviderProxyPayload",
    "fetchMergedProxyPayload",
    "resolveProxyNameFromCachedMenu",
    "/providers/proxies",
    "menuExtraHistory",
    "menuResolvedProxyName",
    "proxyMenuFilePath",
    '"Runtime", "proxies.json"',
    "startProxyMenuPoller",
    "proxyMenuFromFile",
    "buildProxySubmenu",
    "menuNeedsUpdate:",
    "/local/proxy-delay-async",
    "/local/proxy-select-async",
    "proxyConfigOrderedGroups",
    "data.GLOBAL.all",
]:
    if marker not in portable_main:
        errors.append(f"portable v1.2.4 smooth-tray/latency hotfix gate missing: {marker}")
for marker in [
    "backgroundWG sync.WaitGroup",
    "func (s *appState) goBackground(fn func())",
    "func (s *appState) waitBackground()",
    "s.goBackground(s.refreshProxyMenuCache)",
    "s.goBackground(s.refreshStatusCache)",
]:
    if marker not in portable_main:
        errors.append(f"portable v1.2.5 background lifecycle gate missing: {marker}")

portable_tests = (root / "portable-runtime/main_test.go").read_text(encoding="utf-8")
if portable_tests.count("t.Cleanup(state.waitBackground)") < 3:
    errors.append("portable release tests must quiesce background Runtime work before TempDir cleanup")
for forbidden in [
    't.Fatalf("unexpected timeout:',
    't.Fatalf("expected controller bearer secret',
    't.Fatalf("expected no Authorization header',
    't.Fatalf("missing bearer secret',
]:
    if forbidden in portable_tests:
        errors.append(f"portable httptest handler must not call FailNow/Fatalf from a server goroutine: {forbidden}")

for marker in ["isTransientGatewayStatus", "Cloudflare Tunnel 暂时断开", "Error 1033", "fetchMergedProxyPayloadFresh", "staleProxyPayload", "_stale", "_warning", "_profileID", "_snapshot_unix_ms"]:
    if marker not in portable_main:
        errors.append(f"portable v1.2.4 Cloudflare/stale-cache hotfix gate missing: {marker}")
for forbidden in [
    "var data=get('/local/proxies',true)",
    "var data=get('/local/proxy-menu-cache',true)",
    "addSymbol(root,'point.3.connected.trianglepath.dotted')",
]:
    if forbidden in portable_main:
        errors.append(f"portable v1.2.4 hotfix forbidden tray pattern remains: {forbidden}")
for marker in ["/local/menu-preferences", "显示图标", "显示运行状态", "显示网速", "仅显示图标", "scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(1.2"]:
    if marker not in portable_main:
        errors.append(f"portable menu-bar status/speed gate missing: {marker}")
app_model = (root / "MihomoCoreManager/AppModel.swift").read_text(encoding="utf-8")
for marker in ["menuBarShowIcon", "menuBarShowStatus", "menuBarShowSpeed", "menuBarSummary", "menuRate"]:
    if marker not in app_model:
        errors.append(f"native menu-bar status/speed model missing: {marker}")
overview = (root / "MihomoCoreManager/Views/OverviewView.swift").read_text(encoding="utf-8")
for marker in ["实时流量", "快速控制", "Canvas(rendersAsynchronously: true)", "Mihomo Core"]:
    if marker not in overview:
        errors.append(f"native dashboard UI marker missing: {marker}")

# SwiftUI exposes separate fixed-size and flexible frame overloads. A call such
# as `.frame(width: 334, minHeight: 336, alignment: .top)` does not type-check.
# Catch this source pattern before the Xcode Release build.
frame_call_pattern = re.compile(r"\.frame\s*\((.*?)\)", re.S)
fixed_dimension_pattern = re.compile(r"(?<![A-Za-z])(width|height)\s*:")
flex_dimension_pattern = re.compile(
    r"\b(minWidth|idealWidth|maxWidth|minHeight|idealHeight|maxHeight)\s*:"
)
for swift_path in (root / "MihomoCoreManager").rglob("*.swift"):
    swift_text = swift_path.read_text(encoding="utf-8")
    for frame_call in frame_call_pattern.finditer(swift_text):
        args = frame_call.group(1)
        if fixed_dimension_pattern.search(args) and flex_dimension_pattern.search(args):
            line = swift_text.count("\n", 0, frame_call.start()) + 1
            errors.append(
                f"invalid mixed SwiftUI frame overload: "
                f"{swift_path.relative_to(root)}:{line}"
            )

content = (root / "MihomoCoreManager/Views/ContentView.swift").read_text(encoding="utf-8")
models = (root / "MihomoCoreManager/Models.swift").read_text(encoding="utf-8")
subscriptions_view = (root / "MihomoCoreManager/Views/SubscriptionsView.swift").read_text(encoding="utf-8")
logs_view = (root / "MihomoCoreManager/Views/LogsView.swift").read_text(encoding="utf-8")
app_swift = (root / "MihomoCoreManager/MihomoCoreManagerApp.swift").read_text(encoding="utf-8")
for marker in ["case settings", 'case .settings: "设置"']:
    if marker not in models:
        errors.append(f"native Settings tab model gate missing: {marker}")
for marker in ["case proxies", 'case .proxies: "代理切换"', "MihomoRunMode", "MihomoProxy"]:
    if marker not in models:
        errors.append(f"native v1.2.3 proxy model gate missing: {marker}")
for marker in ["ProxySortOption", "case defaultOrder", "case delay", "case quality", "case name", "testURL", "expectedStatus", "testProxyGroup"]:
    if marker not in models:
        errors.append(f"native v1.2.4 proxy model/sort gate missing: {marker}")
if "enum ProxySortOption: String, CaseIterable, Identifiable, Hashable" not in models:
    errors.append("v1.2.4 release regression: ProxySortOption must remain explicitly Hashable")
for marker in ["persistentDetail", "persistentPage(.settings)", "DashboardSettingsView()"]:
    if marker not in content:
        errors.append(f"native persistent tab/settings gate missing: {marker}")
for marker in ["persistentPage(.proxies)", "struct ProxiesView", "运行模式", "代理组", "详细代理", "setProxyMode", "selectProxy"]:
    if marker not in content:
        errors.append(f"native v1.2.3 proxy UI gate missing: {marker}")
for marker in [
    "groupSort",
    "proxySort",
    "ProxySortPicker",
    "groupDetailHeader",
    "groupDetailToolbar",
    "groupMemberList",
    "测速当前组",
    "qualityLess",
    "groupDelayLess",
    "effectiveProxyDelay",
]:
    if marker not in content:
        errors.append(f"native v1.2.4 proxy sort/delay UI gate missing: {marker}")

# v1.2.4/Xcode 16.4 release incident regression gates. Syntax-only Swift
# parsing did not catch these forms, so keep explicit source-level checks.
for marker in [
    "case .some(true): aliveRank = 0",
    "case .none: aliveRank = 1",
    "case .some(false): aliveRank = 2",
    "let history: [MihomoProxyDelaySample]",
    ".onChange(of: busy) { _, newValue in",
]:
    if marker not in content:
        errors.append(f"v1.2.4 Xcode compile guard missing: {marker}")
for forbidden in [
    "case true: aliveRank = 0",
    "case false: aliveRank = 2",
    "let history = Array(proxy?.history.suffix(6) ?? [])",
    "private func sortControl(selection: Binding<ProxySortOption>)",
    ".onChange(of: busy) { newValue in",
]:
    if forbidden in content:
        errors.append(f"v1.2.4 Xcode compile regression returned: {forbidden}")
for marker in ["preferredTestURL: group.testURL"]:
    if marker not in content:
        errors.append(f"native v1.2.4 proxy latency display hotfix missing: {marker}")
for marker in [
    "WindowBehaviorConfigurator",
    "window.isMovable = true",
    "window.titleVisibility = .hidden",
    "window.titlebarAppearsTransparent = true",
    "window.titlebarSeparatorStyle = .none",
    "window.styleMask.insert(.fullSizeContentView)",
    ".ignoresSafeArea(.container, edges: .top)",
    ".padding(.top, 38)",
    "DashboardPalette.primary",
    'Text("管理面板")',
    ".frame(width: 256)",
    "DashboardBackendSelector",
    "BackendPickerPopover",
    '.frame(height: 43)',
    'Text("管理后端")',
    'Text("选择要管理的 Mihomo Core 服务器")',
    '.frame(width: 232)',
]:
    if marker not in content:
        errors.append(f"native window/backend-selector/titlebar gate missing: {marker}")
if "miniBrandMark" in content or 'Text("M")\n                                        .font(.system(size: 12' in content:
    errors.append("native v1.1.1 backend selector must not repeat the M brand tile")
for marker in ["LiveStatusStore", "secretCache", "ensureSubscriptionsLoaded", "ensureLogsLoaded"]:
    if marker not in app_model:
        errors.append(f"native performance gate missing: {marker}")
for marker in [
    "statusRefreshes",
    "proxyBackgroundLoads",
    "proxyByNameCache",
    "markUnavailableIfStale",
    "async let valuesTask",
    "proxyReconcileTokens",
]:
    if marker not in app_model:
        errors.append(f"native v1.2.5 smoothness/safety gate missing: {marker}")
for marker in ["proxyMode", "proxies", "ensureProxiesLoaded", "fetchProxies", "setProxyMode", "selectProxy"]:
    if marker not in app_model:
        errors.append(f"native v1.2.3 proxy operation gate missing: {marker}")
for marker in ["proxyGroupOrder", "proxyDelayResults", "testProxyGroup", "effectiveProxyDelay", "proxyGroupsInDefaultOrder"]:
    if marker not in app_model:
        errors.append(f"native v1.2.4 proxy delay/order model gate missing: {marker}")
for marker in ['name == "GLOBAL"', "GLOBAL.all", "preferredTestURL", "proxy.extra", 'lhs.name == "GLOBAL"']:
    if marker not in app_model:
        errors.append(f"native v1.2.4 order/latency hotfix gate missing: {marker}")
for marker in ["resolvedProxyName", "positiveDelay", "delay > 0", "proxy.now", "positiveLatencyCandidates"]:
    if marker not in app_model:
        errors.append(f"native v1.2.4 provider/nested latency gate missing: {marker}")
for marker in ["isTransientControllerError", "applyLocalProxySelection", "已保留最近一次代理与延时数据", "scheduleProxySelectionReconcile"]:
    if marker not in app_model:
        errors.append(f"native v1.2.4 transient-controller fallback gate missing: {marker}")
for marker in ["currentProxySelection", "proxiesByApplyingSelection", "A just-confirmed PUT remains authoritative for this group"]:
    if marker not in app_model:
        errors.append(f"native v1.2.5 immediate proxy selection refresh gate missing: {marker}")
for marker in ['let currentSelection = model.currentProxySelection', r'.id("\(group.name)|\(currentSelection ?? group.type)")']:
    if marker not in menu:
        errors.append(f"native v1.2.5 status-menu proxy suffix refresh gate missing: {marker}")
if "guard model.selectedSection == .subscriptions" not in subscriptions_view:
    errors.append("subscriptions must load only when its tab becomes active")
if "guard model.selectedSection == .logs" not in logs_view:
    errors.append("logs must load only when its tab becomes active")
for marker in [
    ".windowStyle(.hiddenTitleBar)",
    ".menuBarExtraStyle(.window)",
    "Image(nsImage: menuBarSpeedImage)",
    "MenuBarSpeedImageRenderer.make(",
    "NSImage(size: imageSize, flipped: false)",
    "image.isTemplate = true",
    "NSFont.monospacedDigitSystemFont(ofSize: 8.3, weight: .semibold)",
    "private static let numericWidth: CGFloat = 24",
    "private static let unitWidth: CGFloat = 31",
    "drawSpeedLine(upload, y: 8.6)",
    "drawSpeedLine(download, y: -0.4)",
    '.frame(width: 55, height: 18, alignment: .bottomLeading)',
    '.offset(y: 1)',
    "HStack(alignment: .center, spacing: 5)",
    "if model.menuBarShowIcon",
    "model.menuBarShowStatus && !model.menuBarShowIcon",
]:
    if marker not in app_swift:
        errors.append(f"native compact-window/v1.2.2 menu-bar gate missing: {marker}")
if "private func speedLine(" in app_swift or "VStack(alignment: .leading, spacing: -2)" in app_swift:
    errors.append("native v1.2.2 status-bar body must not use a multiline SwiftUI speed label")
if "menuBarRateParts" not in app_model:
    errors.append("native v1.2.2 menu-bar rate-parts formatter missing")

core_view = (root / "MihomoCoreManager/Views/CoreView.swift").read_text(encoding="utf-8")
update_view = (root / "MihomoCoreManager/Views/UpdateView.swift").read_text(encoding="utf-8")
settings_dashboard = settings.split("struct SettingsRootView: View {", 1)[0]
for rel_name, text in [("OverviewView.swift", overview), ("CoreView.swift", core_view), ("SubscriptionsView.swift", subscriptions_view), ("SettingsView.swift (dashboard)", settings_dashboard)]:
    if "ViewThatFits(in: .horizontal)" in text:
        errors.append(f"duplicate responsive button/view subtree is not allowed in {rel_name}")
for marker in ["DashboardLayout.pageHorizontalPadding", "DashboardLayout.pageVerticalPadding", "DashboardLayout.pageSpacing"]:
    for rel_name, text in [("OverviewView.swift", overview), ("CoreView.swift", core_view), ("SubscriptionsView.swift", subscriptions_view), ("LogsView.swift", logs_view), ("UpdateView.swift", update_view), ("SettingsView.swift (dashboard)", settings_dashboard)]:
        if marker not in text:
            errors.append(f"shared dashboard layout marker missing in {rel_name}: {marker}")
# v1.1.7 regression: initiating button remains visibly busy until the awaited operation completes,
# and press feedback remains intentionally more pronounced than v1.1.6.
for marker in [
    "struct DashboardBusyLabel: View",
    "DashboardBusyCursorAnimator",
    "NSCursor(image: image, hotSpot:",
    "DashboardButtonCursorModifier(busy: busy, reduceMotion: reduceMotion)",
    ".scaleEffect(pressed ? 0.955 : 1)",
    ".spring(response: 0.18, dampingFraction: 0.68)",
    "activeOperation = operationID",
    "waitForUpdateCompletion(",
    "result.running",
    "等待管理面板恢复连接",
]:
    if marker not in content + "\n" + app_model + "\n" + core_view + "\n" + update_view:
        errors.append(f"v1.1.7 regression native button lifecycle gate missing: {marker}")

for marker in [
    "control.classList.add('busy')",
    "control.setAttribute('aria-busy','true')",
    "operation-busy",
    "cursor:progress",
    "waitForUpdateCompletion",
    "scale(.945)",
]:
    if marker not in portable_ui:
        errors.append(f"v1.1.7 regression portable button lifecycle gate missing: {marker}")

# v1.1.8: success notices auto-dismiss only after the current operation exits busy,
# sidebar page buttons use a larger full-row hit target, and persistent pages use
# a real profile/section task identity so first navigation loads immediately.
for marker in [
    "noticeDismissTask",
    "scheduleNoticeDismissIfNeeded",
    "func dismissNotice()",
    "scheduleNoticeDismissIfNeeded()",
    "DashboardNotice(notice: notice) { model.dismissNotice() }",
    "DashboardSidebarButtonStyle",
    ".frame(maxWidth: .infinity, minHeight: 47, alignment: .leading)",
    ".contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))",
    ".scaleEffect(pressed ? 0.972 : 1)",
]:
    if marker not in app_model + "\n" + content:
        errors.append(f"v1.1.8 native interaction gate missing: {marker}")

expected_task_id = '"\\(model.selectedProfileID?.uuidString ?? "none")|\\(model.selectedSection.rawValue)"'
for rel_name, text in [("SettingsView.swift", settings_dashboard), ("LogsView.swift", logs_view)]:
    if expected_task_id not in text:
        errors.append(f"v1.1.8 persistent-page task id missing in {rel_name}")
    if '"\\\\(model.selectedProfileID' in text:
        errors.append(f"v1.1.8 persistent-page task id is still escaped in {rel_name}")

for marker in ["min-height:46px", ".nav button:active", "scale(.955)"]:
    if marker not in portable_ui:
        errors.append(f"v1.1.8 portable sidebar interaction gate missing: {marker}")

# v1.1.9 dropdown regression: keep the compact custom MenuBarExtra panel.
# v1.2.5 splits the high-frequency live summary/Core state into small child
# views so a 1.2 s telemetry tick does not rebuild the full proxy menu tree.
for marker in [
    ".menuBarExtraStyle(.window)",
    'MenuBarLiveSummary()',
    'private var serverCard: some View',
    'MenuBarCoreActions()',
    'private var shortcutGrid: some View',
    'private var updateActions: some View',
    'private var displayOptions: some View',
    'MenuPanelPressStyle',
]:
    if marker not in app_swift + "\n" + menu:
        errors.append(f"v1.1.9 native dropdown regression missing: {marker}")
for marker in ["private struct MenuBarLiveSummary", "private struct MenuBarCoreActions"]:
    if marker not in menu:
        errors.append(f"v1.2.5 native dropdown performance gate missing: {marker}")

# v1.2.0 status-bar body: use independent AppKit labels instead of a multiline
# NSStatusBarButton title so both traffic rows are actually visible.
for marker in [
    "function statusRateParts(raw)",
    "MihomoStatusOverlayView",
    "MihomoStatusLabel",
    "MihomoStatusIconView",
    "statusItem.button.performClick(null)",
    "function renderStatusSpeedOverlay()",
    "upValueLabel.frame=$.NSMakeRect(speedX,9.3,22,10.5)",
    "downValueLabel.frame=$.NSMakeRect(speedX,0.3,22,10.5)",
    "upValueLabel.stringValue=$(up.value)",
    "downValueLabel.stringValue=$(down.value)",
    "statusItem.button.addSubview(statusOverlay)",
    "button.image=null; button.imagePosition=0; button.title=''",
    "serverRoot.title='服务器  ·  '+selectedName",
    "var coreRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('Core 控制'",
    "var toolsRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('管理与工具'",
    "var displayRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('状态栏显示'",
    "function addSymbol(item,name)",
]:
    if marker not in portable_main:
        errors.append(f"v1.2.0 portable status-bar gate missing: {marker}")
if "function renderStatusSpeedOverlay()" in portable_main and "function renderStatusButton()" in portable_main:
    status_overlay = portable_main.split("function renderStatusSpeedOverlay()", 1)[1].split("function renderStatusButton()", 1)[0]
    if "↑" in status_overlay or "↓" in status_overlay:
        errors.append("v1.2.0 status-bar body must not render upload/download arrows")

portable_installer = (root / "scripts/build-portable-installer.sh").read_text(encoding="utf-8")
for marker in ["GOOS=darwin GOARCH=arm64", "MihomoCoreManager.app", "Install-MihomoCoreManager.command", "LSMinimumSystemVersion", "codesign --force --deep --sign -"]:
    if marker not in portable_installer:
        errors.append(f"portable installer gate missing: {marker}")

if ".buttonStyle(.plain)" not in content:
    errors.append("navigation/link button behavior (.plain) missing")
settings_order_markers = ["serverPanel", "connectionPanel(profile: draftBinding)", "corePanel(profile: draftBinding)", "appPanel", "footerActions"]
settings_positions = [settings_dashboard.find(marker) for marker in settings_order_markers]
if any(position < 0 for position in settings_positions) or settings_positions != sorted(settings_positions):
    errors.append("settings blocks must be vertically ordered: server -> connection -> Core -> App/status -> actions")
for marker in ['DashboardPanelHeader(title: "App 与状态栏"', 'appControlCell("显示状态栏按钮"', 'appControlCell("状态栏显示图标"', 'appControlCell("状态栏显示运行状态"', 'appControlCell("状态栏显示实时网速"', 'appControlCell("状态刷新间隔"', 'appControlCell("默认日志行数"']:
    if marker not in settings_dashboard:
        errors.append(f"two-column App/status settings gate missing: {marker}")
if ".frame(height: 336)" not in overview: errors.append("overview paired panels must use the same 336pt height")
if ".frame(height: 300)" not in core_view: errors.append("Core paired panels must use the same 300pt height")

for marker in ['data-nav="settings"', 'data-view="settings"', 'contain:layout paint style', "pageLoaded=new Set()", "document.hidden", 'id="pMenuIcon"', "showIcon:icon.checked"]:
    if marker not in portable_ui:
        errors.append(f"portable settings/performance gate missing: {marker}")
for marker in ["secretCache", "statusData", "startStatusPoller", "statusFromFile", "STATUS_FILE", "clearStatusFile"]:
    if marker not in portable_main:
        errors.append(f"portable status-cache performance gate missing: {marker}")
for marker in [
    "func newHTTPClient()",
    "http.DefaultTransport.(*http.Transport).Clone()",
    "statusFetchMu.TryLock()",
    "remoteWithPolicy",
    "hasRecentGood",
    "function proxyMenuStructureSignature(data)",
]:
    if marker not in portable_main:
        errors.append(f"portable v1.2.5 smoothness/safety gate missing: {marker}")
if "Object.keys(proxyMenuRootByGroup).forEach(refreshProxyMenuRootTitle)" in portable_main:
    errors.append("portable v1.2.5 proxy-menu refresh must not relayout every group on unchanged snapshots")
if "d=get('/local/status',quiet===true)" not in portable_main:
    errors.append("portable recoverable menu refresh fallback missing")
if "scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(1.2" not in portable_main:
    errors.append("portable menu refresh timer missing")
if "speedHeader.title='↑  上传  '+fmtRate(lastUp)+'      ↓  下载  '+fmtRate(lastDown)" not in portable_main:
    errors.append("portable v1.2.5 menu dropdown speed must be a single line")
for marker in [
    "proxyEndSeparator=$.NSMenuItem.separatorItem; menu.addItem(proxyEndSeparator)",
    "var index=proxyEndSeparator?menu.indexOfItem(proxyEndSeparator):menu.indexOfItem(coreRoot)",
    "rect.size.height-22",
    "applyProxyMenuSelectionSnapshot",
    "time.Sleep(220 * time.Millisecond)",
    "proxyMenuRootByGroup={}",
    "function proxyMenuRootTitle(group)",
    "function refreshProxyMenuRootTitle(group)",
    "refreshProxyMenuRootTitle(payload.group)",
    "function proxyMenuStructureSignature(data)",
    "proxyMenuStructureKey",
    "proxyPendingReconcile[payload.group]=true",
    "if(oldCurrent!==newCurrent)refreshProxyMenuRootTitle(group)",
]:
    if marker not in portable_main:
        errors.append(f"portable v1.2.5 menu/layout refresh gate missing: {marker}")
for marker in [
    "grid-template-columns:256px minmax(0,1fr)",
    "grid-template-rows:minmax(0,1fr)",
    ".brand-product{color:var(--text)",
    'class="brand-head"',
    'class="brand-product">Mihomo Core',
    'class="brand-title">管理面板',
    "A just-confirmed PUT is authoritative for this group",
]:
    if marker not in portable_ui:
        errors.append(f"portable v1.2.5 unified left-right/header UI gate missing: {marker}")
if '<div class="titlebar">' in portable_ui or "--titlebar:" in portable_ui:
    errors.append("portable v1.2.5 main window must not render a separate title bar")
for marker in [
    "menuSectionDivider",
    ".frame(height: 42)",
    ".padding(.top, 38)",
    "DashboardPalette.primary",
    "window.backgroundColor = NSColor(",
]:
    if marker not in menu + "\n" + content:
        errors.append(f"native v1.2.5 unified window/header gate missing: {marker}")
for marker in [
    "MihomoWindowDragView",
    "performWindowDragWithEvent",
    "function fmtMenuRate(raw)",
    "function statusRateParts(raw)",
    "function renderStatusSpeedOverlay()",
    "function renderStatusButton()",
    "function safeSingleLineTitle()",
    "Never allow a cosmetic status-bar failure to terminate the whole App",
    "fallbackMenuScript",
    "starting recovery shell",
    "menubar.log",
    "statusItem.button.addSubview(statusOverlay)",
    "_menu_updated_unix_ms",
    "missingSnapshotTicks>=4",
    "var showIcon=true, showStatus=true, showSpeed=true",
    "prefIconItem=addItem(displayMenu,'显示图标','toggleShowIcon:','')",
    "button.imagePosition=hasText?2:1",
    "handleSubscriptions",
    "subscriptionReloadTimedOut",
    "restart-fallback",
    'coreLifecycleAction("stop")',
    'coreLifecycleAction("start")',
]:
    if marker not in portable_main:
        errors.append(f"portable v1.1.1 crash-recovery/native-speed gate missing: {marker}")
for forbidden in ["ObjC.import('QuartzCore')", "CATextLayer", "button.cell.wraps=true", "button.cell.usesSingleLineMode=false", "NSBaselineOffsetAttributeName"]:
    if forbidden in portable_main:
        errors.append(f"portable v1.1.1 startup path still contains crash-prone marker: {forbidden}")
for marker in [
    "profile-trigger-label",
    "height:43px",
    "min-height:52px",
    "管理后端",
    "width:100%",
    "max-width:100%",
    "profile-option-title",
]:
    if marker not in portable_ui:
        errors.append(f"portable v1.1.1 backend selector gate missing: {marker}")
for forbidden in ["profile-trigger-icon", "profile-option-icon", "profile-caption", "width:304px"]:
    if forbidden in portable_ui:
        errors.append(f"portable v1.1.1 backend selector still contains removed brand-card marker: {forbidden}")

with (root / "MihomoCoreManager/Info.plist").open("rb") as f:
    plist = plistlib.load(f)
if not plist.get("NSAppTransportSecurity", {}).get("NSAllowsArbitraryLoads"):
    errors.append("ATS compatibility flag missing for explicit per-profile HTTP support")

workflow = (root / ".github/workflows/release.yml").read_text(encoding="utf-8")
ci_workflow = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
build_release = (root / "scripts/build-release.sh").read_text(encoding="utf-8")
release_preflight = (root / "scripts/release-preflight.py").read_text(encoding="utf-8")
for marker in [
    'if args.strict_macos:',
    '"scripts/build-source-manifest.py", "--write"',
    'release preflight: refreshed stale source manifest from exact checkout',
    '"scripts/build-source-manifest.py", "--check"',
]:
    if marker not in release_preflight:
        errors.append(f"v1.2.5 strict preflight self-heal gate missing: {marker}")

for marker in [
    '"xcrun", "--sdk", "macosx", "--show-sdk-path"',
    '"xcrun", "--sdk", "macosx", "swiftc"',
    '"-sdk", macos_sdk',
    '"-target", swift_target',
    'swift_target = f"arm64-apple-macos{deployment_target}"',
]:
    if marker not in release_preflight:
        errors.append(f"v1.2.5 Xcode SDK-bound Swift probe gate missing: {marker}")

simulate_release = (root / "scripts/simulate-release.sh").read_text(encoding="utf-8")
for marker in [
    "-count=100",
    "-shuffle=on -count=3",
    "go test -race -timeout=120s -count=1",
    "go vet ./...",
    "GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go test -c",
    "darwin/arm64 Go test cross-compile: PASS",
    "native unsigned release simulation: PASS",
    "release-simulation-verify",
]:
    if marker not in simulate_release:
        errors.append(f"v1.2.5 release simulation stress gate missing: {marker}")
release_text = workflow + "\n" + build_release
for marker in ["macos-15", "notarytool", "productbuild", "gh release", "SHA256SUMS.txt"]:
    if marker not in release_text:
        errors.append(f"release gate missing: {marker}")
for marker in [
    "SWIFT_ENABLE_BATCH_MODE=NO",
    "xcodebuild-release.log",
    "Xcode compiler diagnostics",
    "xcrun swiftc --version",
]:
    if marker not in build_release:
        errors.append(f"v1.2.4 Xcode diagnostics/build guard missing: {marker}")
for marker in [
    "bash scripts/simulate-release.sh",
    "真实 macOS arm64 发布全链路模拟",
    "Upload Xcode diagnostics on failure",
    "build/xcodebuild-release.log",
    "python3 scripts/build-source-manifest.py --write",
]:
    if marker not in workflow + "\n" + ci_workflow:
        errors.append(f"v1.2.5 release-engineering guard missing: {marker}")

if "bash scripts/build-release.sh --unsigned" not in simulate_release:
    errors.append("canonical release simulation must use --unsigned native build by default")
for marker in [
    "actions/setup-go@v6",
    "go-version-file: portable-runtime/go.mod",
    "cache: false",
    "bash scripts/simulate-release.sh",
    'gh release upload "$TAG" dist/* dist-portable/* --clobber',
    'test -f "MihomoCoreManager-${TAG}-arm64-portable-installer.zip"',
]:
    if marker not in workflow:
        errors.append(f"v1.2.2 GitHub Release portable parity gate missing: {marker}")
for marker in [
    "actions/setup-go@v6",
    "go-version-file: portable-runtime/go.mod",
    "cache: false",
    "bash scripts/simulate-release.sh",
    "Apple Silicon arm64 full release simulation",
    "dist-portable/",
]:
    if marker not in ci_workflow:
        errors.append(f"v1.2.2 macOS CI portable parity gate missing: {marker}")
for forbidden in ["secrets.APPLE_", "校验签名与公证 Secrets", "导入 Developer ID 证书"]:
    if forbidden in workflow:
        errors.append(f"unsigned release workflow must not require Apple signing secrets: {forbidden}")

# Never ship an obvious hard-coded secret assignment.
for path in (root / "MihomoCoreManager").rglob("*.swift"):
    text = path.read_text(encoding="utf-8")
    if re.search(r'(?i)(secret|token)\s*=\s*"[^"\\]{12,}"', text):
        errors.append(f"possible hard-coded credential: {path.relative_to(root)}")

if errors:
    for error in errors: print("FAIL:", error, file=sys.stderr)
    raise SystemExit(1)
print(f"source validation: PASS (v{version}, arm64, menu/API/settings/release gates)")
