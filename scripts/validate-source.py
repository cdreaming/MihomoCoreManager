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
    "SOURCE-SHA256SUMS.txt",
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
if 'Authorization' not in client or 'Bearer' not in client: errors.append("Bearer authentication missing")
if '.convertToSnakeCase' not in client: errors.append("JSON POST encoding must preserve v4 snake_case keys")
for marker in ["shouldRetrySubscriptionApplyWithRestart", "热重载超时", "action(.stop", "action(.start", "operationFailed"]:
    if marker not in client + "\n" + (root / "MihomoCoreManager/Models.swift").read_text(encoding="utf-8"):
        errors.append(f"native subscription timeout recovery missing: {marker}")

menu = (root / "MihomoCoreManager/Views/MenuBarView.swift").read_text(encoding="utf-8")
for marker in ["显示图标", "显示运行状态", "显示网速", "仅显示图标", "启动 Core", "停止 Core", "重启 Core", "重载配置", "应用订阅 + 热重载", "订阅管理…", "运行日志…", "检查项目更新", "开始项目升级", "打开 MetaCubeXD", "设置…"]:
    if marker not in menu: errors.append(f"menu function missing: {marker}")

settings = (root / "MihomoCoreManager/Views/SettingsView.swift").read_text(encoding="utf-8")
for marker in ["Management URL", "Core Secret", "Direct Core Controller URL", "config.yaml path", "MetaCubeXD URL", "允许不安全 HTTP"]:
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

content = (root / "MihomoCoreManager/Views/ContentView.swift").read_text(encoding="utf-8")
models = (root / "MihomoCoreManager/Models.swift").read_text(encoding="utf-8")
subscriptions_view = (root / "MihomoCoreManager/Views/SubscriptionsView.swift").read_text(encoding="utf-8")
logs_view = (root / "MihomoCoreManager/Views/LogsView.swift").read_text(encoding="utf-8")
app_swift = (root / "MihomoCoreManager/MihomoCoreManagerApp.swift").read_text(encoding="utf-8")
for marker in ["case settings", 'case .settings: "设置"']:
    if marker not in models:
        errors.append(f"native Settings tab model gate missing: {marker}")
for marker in ["persistentDetail", "persistentPage(.settings)", "DashboardSettingsView()"]:
    if marker not in content:
        errors.append(f"native persistent tab/settings gate missing: {marker}")
for marker in [
    "WindowBehaviorConfigurator",
    "window.isMovable = true",
    "DashboardBackendSelector",
    "BackendPickerPopover",
    '.frame(height: 43)',
    'Text("管理后端")',
    'Text("选择要管理的 Mihomo Core 服务器")',
    '.frame(width: 206)',
]:
    if marker not in content:
        errors.append(f"native v1.0.9 window/backend-selector gate missing: {marker}")
if "miniBrandMark" in content or 'Text("M")\n                                        .font(.system(size: 12' in content:
    errors.append("native v1.0.9 backend selector must not repeat the M brand tile")
for marker in ["LiveStatusStore", "secretCache", "ensureSubscriptionsLoaded", "ensureLogsLoaded"]:
    if marker not in app_model:
        errors.append(f"native performance gate missing: {marker}")
if "guard model.selectedSection == .subscriptions" not in subscriptions_view:
    errors.append("subscriptions must load only when its tab becomes active")
if "guard model.selectedSection == .logs" not in logs_view:
    errors.append("logs must load only when its tab becomes active")
for marker in [
    'Text("↓")',
    'Text("↑")',
    'model.menuRateCompact(live.status?.speed?.down)',
    'model.menuRateCompact(live.status?.speed?.up)',
    "HStack(alignment: .center, spacing: 5)",
    "model.menuBarShowStatus && model.menuBarShowSpeed",
    "if model.menuBarShowIcon",
]:
    if marker not in app_swift:
        errors.append(f"native compact two-line menu-bar layout gate missing: {marker}")
if "menuRateCompact" not in app_model:
    errors.append("native compact menu-rate formatter missing")

for marker in ['data-nav="settings"', 'data-view="settings"', 'contain:layout paint style', "pageLoaded=new Set()", "document.hidden", 'id="pMenuIcon"', "showIcon:icon.checked"]:
    if marker not in portable_ui:
        errors.append(f"portable settings/performance gate missing: {marker}")
for marker in ["secretCache", "statusData", "startStatusPoller", "statusFromFile", "STATUS_FILE", "clearStatusFile"]:
    if marker not in portable_main:
        errors.append(f"portable status-cache performance gate missing: {marker}")
if "d=get('/local/status',quiet===true)" not in portable_main:
    errors.append("portable recoverable menu refresh fallback missing")
if "scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(1.2" not in portable_main:
    errors.append("portable menu refresh timer missing")
if "upHeader.title='↑ 上传    '+fmtRate(lastUp)" not in portable_main or "downHeader.title='↓ 下载    '+fmtRate(lastDown)" not in portable_main:
    errors.append("portable menu dropdown speed headers missing")
for marker in [
    "MihomoWindowDragView",
    "performWindowDragWithEvent",
    "function fmtMenuRate(raw)",
    "function renderStatusButton()",
    "function safeSingleLineTitle()",
    "Never allow a cosmetic status-bar failure to terminate the whole App",
    "fallbackMenuScript",
    "starting recovery shell",
    "menubar.log",
    "var down='↓ '+fmtMenuRate(lastDown), up='↑ '+fmtMenuRate(lastUp)",
    "_menu_updated_unix_ms",
    "missingSnapshotTicks>=4",
    "var showIcon=true, showStatus=true, showSpeed=true",
    "prefIconItem=item('显示图标','toggleShowIcon:')",
    "button.imagePosition=hasText?2:1",
    "handleSubscriptions",
    "subscriptionReloadTimedOut",
    "restart-fallback",
    'coreLifecycleAction("stop")',
    'coreLifecycleAction("start")',
]:
    if marker not in portable_main:
        errors.append(f"portable v1.0.9 crash-recovery/native-speed gate missing: {marker}")
for forbidden in ["ObjC.import('QuartzCore')", "CATextLayer", "button.cell.wraps=true", "button.cell.usesSingleLineMode=false", "NSBaselineOffsetAttributeName"]:
    if forbidden in portable_main:
        errors.append(f"portable v1.0.9 startup path still contains crash-prone marker: {forbidden}")
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
        errors.append(f"portable v1.0.9 backend selector gate missing: {marker}")
for forbidden in ["profile-trigger-icon", "profile-option-icon", "profile-caption", "width:304px"]:
    if forbidden in portable_ui:
        errors.append(f"portable v1.0.9 backend selector still contains removed brand-card marker: {forbidden}")

with (root / "MihomoCoreManager/Info.plist").open("rb") as f:
    plist = plistlib.load(f)
if not plist.get("NSAppTransportSecurity", {}).get("NSAllowsArbitraryLoads"):
    errors.append("ATS compatibility flag missing for explicit per-profile HTTP support")

workflow = (root / ".github/workflows/release.yml").read_text(encoding="utf-8")
build_release = (root / "scripts/build-release.sh").read_text(encoding="utf-8")
release_text = workflow + "\n" + build_release
for marker in ["macos-15", "notarytool", "productbuild", "gh release", "SHA256SUMS.txt"]:
    if marker not in release_text: errors.append(f"release gate missing: {marker}")

# Never ship an obvious hard-coded secret assignment.
for path in (root / "MihomoCoreManager").rglob("*.swift"):
    text = path.read_text(encoding="utf-8")
    if re.search(r'(?i)(secret|token)\s*=\s*"[^"\\]{12,}"', text):
        errors.append(f"possible hard-coded credential: {path.relative_to(root)}")

if errors:
    for error in errors: print("FAIL:", error, file=sys.stderr)
    raise SystemExit(1)
print(f"source validation: PASS (v{version}, arm64, menu/API/settings/release gates)")
