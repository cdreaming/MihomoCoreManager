package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestJoinURL(t *testing.T) {
	got, err := joinURL("https://example.com/base", "/api/status", false, nil)
	if err != nil {
		t.Fatal(err)
	}
	if got != "https://example.com/base/api/status" {
		t.Fatalf("unexpected URL: %s", got)
	}
}

func TestHTTPGate(t *testing.T) {
	if _, err := normalizeBase("http://example.com", false); err == nil {
		t.Fatal("plain HTTP must be rejected unless enabled")
	}
	if _, err := normalizeBase("http://example.com", true); err != nil {
		t.Fatal(err)
	}
}

func TestMenuPreferences(t *testing.T) {
	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{
			SelectedID:      "test",
			Profiles:        []Profile{{ID: "test", Name: "test", ManagementURL: "https://example.com"}},
			MenuPreferences: &MenuPreferences{ShowIcon: true, ShowStatus: true, ShowSpeed: true},
		},
	}

	req := httptest.NewRequest(http.MethodPost, "/local/menu-preferences", strings.NewReader(`{"showIcon":true,"showStatus":false,"showSpeed":true}`))
	rec := httptest.NewRecorder()
	state.handleMenuPreferences(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("unexpected status: %d (%s)", rec.Code, rec.Body.String())
	}

	var got map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got["showIcon"] != true || got["showStatus"] != false || got["showSpeed"] != true {
		t.Fatalf("unexpected prefs: %#v", got)
	}

	req = httptest.NewRequest(http.MethodGet, "/local/menu-preferences", nil)
	rec = httptest.NewRecorder()
	state.handleMenuPreferences(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("unexpected status: %d", rec.Code)
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got["showIcon"] != true || got["showStatus"] != false || got["showSpeed"] != true {
		t.Fatalf("prefs did not persist in state: %#v", got)
	}
}

func TestSubscriptionReloadTimeoutFallsBackToSafeRestart(t *testing.T) {
	running := true
	subscriptionPosts := 0
	actions := make([]string, 0, 2)

	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/subscriptions":
			if r.Method == http.MethodGet {
				_, _ = w.Write([]byte(`{"ok":true,"subscriptions":{}}`))
				return
			}
			subscriptionPosts++
			if running {
				w.WriteHeader(http.StatusBadRequest)
				_, _ = w.Write([]byte(`{"ok":false,"message":"应用失败: [mihomo-config-render] Mihomo 热重载失败: timed out；已恢复修改前 subscriptions.conf/config.yaml"}`))
				return
			}
			_, _ = w.Write([]byte(`{"ok":true,"message":"订阅已保存；Mihomo Core 当前已停止，将在下次启动时使用新配置"}`))
		case "/api/action":
			var in map[string]string
			_ = json.NewDecoder(r.Body).Decode(&in)
			action := in["action"]
			actions = append(actions, action)
			switch action {
			case "stop":
				running = false
			case "start":
				running = true
			}
			_, _ = w.Write([]byte(`{"ok":true,"message":"ok"}`))
		case "/api/status":
			active := "false"
			if running {
				active = "true"
			}
			_, _ = w.Write([]byte(`{"ok":true,"service":{"active":` + active + `},"speed":{"up":0,"down":0}}`))
		default:
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write([]byte(`{"ok":false,"message":"not found"}`))
		}
	}))
	defer remote.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{
			SelectedID: "test",
			Profiles: []Profile{{
				ID: "test", Name: "test", ManagementURL: remote.URL, AllowInsecureHTTP: true,
			}},
		},
		client:      remote.Client(),
		secretCache: map[string]string{"test": "secret"},
	}

	req := httptest.NewRequest(http.MethodPost, "/local/subscriptions", strings.NewReader(`{"subscriptions":{"BYG":"https://example.com/sub"}}`))
	rec := httptest.NewRecorder()
	state.handleSubscriptions(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("unexpected status: %d (%s)", rec.Code, rec.Body.String())
	}
	if subscriptionPosts != 2 {
		t.Fatalf("expected initial transaction + stopped retry, got %d posts", subscriptionPosts)
	}
	if strings.Join(actions, ",") != "stop,start" {
		t.Fatalf("expected safe restart sequence, got %#v", actions)
	}
	if !strings.Contains(rec.Body.String(), `"applyMode":"restart-fallback"`) {
		t.Fatalf("fallback result missing: %s", rec.Body.String())
	}
	if !running {
		t.Fatal("Core should be running again after fallback")
	}
}

func TestStatusSnapshotAddsMenuTimestampAndKeepsSpeed(t *testing.T) {
	state := &appState{path: filepath.Join(t.TempDir(), "settings.json")}
	state.writeStatusFile([]byte(`{"service":{"active":true},"speed":{"up":1234,"down":5678}}`))
	data, err := os.ReadFile(state.statusFilePath())
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatal(err)
	}
	if _, ok := got["_menu_updated_unix_ms"]; !ok {
		t.Fatal("menu status snapshot is missing freshness timestamp")
	}
	speed, ok := got["speed"].(map[string]any)
	if !ok || speed["up"] != float64(1234) || speed["down"] != float64(5678) {
		t.Fatalf("speed fields were not preserved: %#v", got["speed"])
	}
}

func TestInvalidateStatusCacheRemovesSnapshot(t *testing.T) {
	state := &appState{path: filepath.Join(t.TempDir(), "settings.json")}
	state.writeStatusFile([]byte(`{"service":{"active":true}}`))
	if _, err := os.Stat(state.statusFilePath()); err != nil {
		t.Fatalf("status snapshot was not created: %v", err)
	}
	state.invalidateStatusCache()
	if _, err := os.Stat(state.statusFilePath()); !os.IsNotExist(err) {
		t.Fatalf("status snapshot should be removed after invalidation, err=%v", err)
	}
}

func TestMenuScriptUsesCachedSnapshotNativeDragAndV120StatusSpeed(t *testing.T) {
	script := menuScript("http://127.0.0.1:12345", "token", "/tmp/status.json")
	for _, marker := range []string{
		"function statusFromFile()",
		"_menu_updated_unix_ms",
		"missingSnapshotTicks>=4",
		"MihomoWindowDragView",
		"performWindowDragWithEvent",
		"function fmtMenuRate(raw)",
		"function statusRateParts(raw)",
		"MihomoStatusOverlayView",
		"MihomoStatusLabel",
		"MihomoStatusIconView",
		"statusItem.button.performClick(null)",
		"function renderStatusSpeedOverlay()",
		"function renderStatusButton()",
		"function safeSingleLineTitle()",
		"var showIcon=true, showStatus=true, showSpeed=true",
		"prefIconItem=addItem(displayMenu,'显示图标','toggleShowIcon:','')",
		"statusItem.button.addSubview(statusOverlay)",
		"upValueLabel.frame=$.NSMakeRect(speedX,9.3,22,10.5)",
		"downValueLabel.frame=$.NSMakeRect(speedX,0.3,22,10.5)",
		"upValueLabel.stringValue=$(up.value)",
		"downValueLabel.stringValue=$(down.value)",
		"button.image=null; button.imagePosition=0; button.title=''",
		"Never allow a cosmetic status-bar failure to terminate the whole App",
		"upHeader.title='↑  上传                     '+fmtRate(lastUp)",
		"downHeader.title='↓  下载                     '+fmtRate(lastDown)",
		"var coreRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('Core 控制'",
		"var toolsRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('管理与工具'",
		"var displayRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('状态栏显示'",
		"function addSymbol(item,name)",
	} {
		if !strings.Contains(script, marker) {
			t.Fatalf("menu script missing v1.2.0 marker %q", marker)
		}
	}
	for _, forbidden := range []string{"button.cell.wraps=true", "button.cell.usesSingleLineMode=false", "NSBaselineOffsetAttributeName", "CATextLayer", "function speedImage(up,down)", "title=up+'\\n'+down"} {
		if strings.Contains(script, forbidden) {
			t.Fatalf("v1.2.0 status-bar startup path must avoid marker %q", forbidden)
		}
	}
	overlayStart := strings.Index(script, "function renderStatusSpeedOverlay()")
	overlayEnd := strings.Index(script, "function renderStatusButton()")
	if overlayStart < 0 || overlayEnd <= overlayStart {
		t.Fatal("could not isolate v1.2.0 status speed overlay")
	}
	overlay := script[overlayStart:overlayEnd]
	if strings.ContainsAny(overlay, "↑↓") {
		t.Fatal("status-bar body must not include upload/download arrows")
	}
	if strings.Contains(script, "%!") {
		t.Fatalf("menu script contains fmt formatting errors")
	}
}

func TestFallbackMenuScriptIsMinimalAndUsable(t *testing.T) {
	script := fallbackMenuScript("http://127.0.0.1:12345")
	for _, marker := range []string{"WKWebView", "恢复模式：状态栏渲染已降级", "打开主窗口…", "show(); app.run"} {
		if !strings.Contains(script, marker) {
			t.Fatalf("fallback menu script missing marker %q", marker)
		}
	}
	for _, forbidden := range []string{"CATextLayer", "attributedTitle", "button.cell", "NSBaselineOffsetAttributeName"} {
		if strings.Contains(script, forbidden) {
			t.Fatalf("fallback must stay minimal, found %q", forbidden)
		}
	}
}

func TestPortableInteractionRegressionV118(t *testing.T) {
	page, err := assets.ReadFile("ui/index.html")
	if err != nil {
		t.Fatal(err)
	}
	text := string(page)
	for _, marker := range []string{
		"control.classList.add('busy')",
		"control.setAttribute('aria-busy','true')",
		"operation-busy",
		"cursor:progress",
		"waitForUpdateCompletion",
		"项目升级中…",
		"scale(.945)",
		"min-height:46px",
		".nav button:active",
		"scale(.955)",
	} {
		if !strings.Contains(text, marker) {
			t.Fatalf("portable v1.1.8 interaction regression missing marker %q", marker)
		}
	}
}

func TestPortableVersionV122(t *testing.T) {
	if appVersion != "1.2.2" || buildNumber != "122" {
		t.Fatalf("unexpected portable version/build: %s/%s", appVersion, buildNumber)
	}
}
