package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type roundTripperFunc func(*http.Request) (*http.Response, error)

func (f roundTripperFunc) RoundTrip(r *http.Request) (*http.Response, error) {
	return f(r)
}

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

func TestLANHostClassification(t *testing.T) {
	for _, host := range []string{
		"localhost", "nas", "server.local", "router.lan", "host.home.arpa",
		"127.0.0.1", "10.0.0.8", "172.16.1.9", "192.168.50.4", "169.254.10.2", "::1", "fd00::10",
	} {
		if !isLANHost(host) {
			t.Errorf("expected LAN host classification for %q", host)
		}
	}
	for _, host := range []string{"example.com", "cloudflare.com", "8.8.8.8", "1.1.1.1"} {
		if isLANHost(host) {
			t.Errorf("public host must not be classified as LAN: %q", host)
		}
	}
}

func TestBackendProxyAlwaysBypassesExplicitLANHost(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "http://192.168.20.15:8080/api/status", nil)
	proxyURL, err := backendProxy(req)
	if err != nil {
		t.Fatal(err)
	}
	if proxyURL != nil {
		t.Fatalf("LAN backend must be connected directly, got proxy %s", proxyURL)
	}
}

func TestAdaptivePollDelayBacksOffAndCaps(t *testing.T) {
	base := 1200 * time.Millisecond
	if got := adaptivePollDelay(base, 30*time.Second, 0); got != base {
		t.Fatalf("healthy delay changed: %v", got)
	}
	if got := adaptivePollDelay(base, 30*time.Second, 1); got != 2400*time.Millisecond {
		t.Fatalf("first failure should back off to 2x, got %v", got)
	}
	if got := adaptivePollDelay(base, 30*time.Second, 9); got != 30*time.Second {
		t.Fatalf("backoff must cap at 30s, got %v", got)
	}
}

func TestControllerURLStripsUIPrefixAndPreservesExplicitPort(t *testing.T) {
	normalized, err := normalizedControllerString("http://192.168.9.202:9090/ui/", true)
	if err != nil {
		t.Fatal(err)
	}
	if normalized != "http://192.168.9.202:9090" {
		t.Fatalf("unexpected normalized controller URL: %s", normalized)
	}
	target, err := joinURL(normalized, "/version", true, nil)
	if err != nil {
		t.Fatal(err)
	}
	if target != "http://192.168.9.202:9090/version" {
		t.Fatalf("unexpected controller target: %s", target)
	}
}

func TestControllerURLDoesNotInventPort(t *testing.T) {
	normalized, err := normalizedControllerString("http://mihomo.lan/ui/", true)
	if err != nil {
		t.Fatal(err)
	}
	if normalized != "http://mihomo.lan" {
		t.Fatalf("controller URL must not auto-add a port: %s", normalized)
	}
}

func TestJoinProxyURLEscapesGroupAsSinglePathSegment(t *testing.T) {
	got, err := joinProxyURL("https://example.com/controller", "HK / Auto", false)
	if err != nil {
		t.Fatal(err)
	}
	if got != "https://example.com/controller/proxies/HK%20%2F%20Auto" {
		t.Fatalf("unexpected proxy URL: %s", got)
	}
}

func TestJoinGroupDelayURLEscapesGroupAndQuery(t *testing.T) {
	got, err := joinGroupDelayURL(
		"https://example.com/controller",
		"HK / Auto",
		false,
		url.Values{"url": []string{"https://example.com/generate_204"}, "timeout": []string{"5000"}},
	)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(got, "https://example.com/controller/group/HK%20%2F%20Auto/delay?") {
		t.Fatalf("unexpected group delay URL: %s", got)
	}
	if !strings.Contains(got, "timeout=5000") || !strings.Contains(got, "url=https%3A%2F%2Fexample.com%2Fgenerate_204") {
		t.Fatalf("group delay query missing: %s", got)
	}
}

func TestGroupDelayCacheDecoratesSharedProxyData(t *testing.T) {
	controller := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch {
		case r.URL.EscapedPath() == "/group/HK%20%2F%20Auto/delay" && r.Method == http.MethodGet:
			if r.URL.Query().Get("timeout") != "5000" {
				t.Errorf("unexpected timeout: %s", r.URL.RawQuery)
				http.Error(w, "unexpected timeout", http.StatusBadRequest)
				return
			}
			_, _ = w.Write([]byte(`{"Shared-A":88,"Only-HK":143}`))
		case r.URL.Path == "/proxies" && r.Method == http.MethodGet:
			_, _ = w.Write([]byte(`{"proxies":{"HK / Auto":{"name":"HK / Auto","type":"Selector","now":"Shared-A","all":["Shared-A","Only-HK"]},"US":{"name":"US","type":"Selector","now":"Shared-A","all":["Shared-A"]},"Shared-A":{"name":"Shared-A","type":"Shadowsocks","alive":true},"Only-HK":{"name":"Only-HK","type":"Shadowsocks","alive":true}}}`))
		case r.URL.Path == "/group" && r.Method == http.MethodGet:
			_, _ = w.Write([]byte(`{"proxies":[{"name":"HK / Auto","type":"Selector","all":["Shared-A","Only-HK"]},{"name":"US","type":"Selector","all":["Shared-A"]}]}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer controller.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{
			SelectedID: "test",
			Profiles: []Profile{{
				ID: "test", Name: "test", ManagementURL: controller.URL,
				CoreControllerURL: controller.URL, AllowInsecureHTTP: true,
			}},
		},
		client:          controller.Client(),
		secretCache:     map[string]string{"test": ""},
		proxyDelayCache: map[string]map[string]int{},
	}
	t.Cleanup(state.waitBackground)

	rec := httptest.NewRecorder()
	state.handleProxyDelay(rec, httptest.NewRequest(
		http.MethodPost,
		"/local/proxy-delay",
		strings.NewReader(`{"group":"HK / Auto","url":"https://example.com/generate_204","timeout":5000}`),
	))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"Shared-A":88`) {
		t.Fatalf("group delay failed: %d %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	state.handleProxies(rec, httptest.NewRequest(http.MethodGet, "/local/proxies", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("proxy fetch failed: %d %s", rec.Code, rec.Body.String())
	}
	var payload struct {
		Proxies map[string]map[string]any `json:"proxies"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if got := int(payload.Proxies["Shared-A"]["lastTestDelay"].(float64)); got != 88 {
		t.Fatalf("shared delay cache missing, got %d", got)
	}
	if _, ok := payload.Proxies["US"]["lastTestDelay"]; ok {
		t.Fatal("group object should not receive a node delay unless it was measured by name")
	}

	rec = httptest.NewRecorder()
	state.handleProxyGroups(rec, httptest.NewRequest(http.MethodGet, "/local/proxy-groups", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"HK / Auto"`) {
		t.Fatalf("group order fetch failed: %d %s", rec.Code, rec.Body.String())
	}
}

func TestDecorateProxyPayloadUsesExtraLatencyAndExplicitTestWins(t *testing.T) {
	state := &appState{
		proxyDelayCache: map[string]map[string]int{},
	}
	raw := []byte(`{"proxies":{"Node-A":{"name":"Node-A","history":[],"extra":{"https://a.example/test":{"alive":true,"history":[{"time":"2026-09-11T01:00:00Z","delay":180}]},"https://b.example/test":{"alive":true,"history":[{"time":"2026-09-11T02:00:00Z","delay":95}]}}}}}`)
	decorated, err := state.decorateProxyPayload("p1", raw)
	if err != nil {
		t.Fatal(err)
	}
	var payload struct {
		Proxies map[string]map[string]any `json:"proxies"`
	}
	if err := json.Unmarshal(decorated, &payload); err != nil {
		t.Fatal(err)
	}
	if got := int(payload.Proxies["Node-A"]["lastTestDelay"].(float64)); got != 95 {
		t.Fatalf("expected newest extra latency 95ms, got %d", got)
	}

	state.cacheProxyDelays("p1", map[string]int{"Node-A": 61})
	decorated, err = state.decorateProxyPayload("p1", raw)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(decorated, &payload); err != nil {
		t.Fatal(err)
	}
	if got := int(payload.Proxies["Node-A"]["lastTestDelay"].(float64)); got != 61 {
		t.Fatalf("explicit group test must override historical extra latency, got %d", got)
	}
}

func TestStatusMenuProxyHotfixUsesCacheLazySubmenusAndAsyncActions(t *testing.T) {
	script := menuScript("http://127.0.0.1:12345", "token", "/tmp/status.json")
	for _, marker := range []string{
		"PROXY_FILE",
		"replace(/status\\.json$/, 'proxies.json')",
		"function proxyMenuFromFile()",
		"function proxyConfigOrderedGroups(data)",
		"data.GLOBAL.all",
		"function buildProxySubmenu(sub)",
		"'menuNeedsUpdate:'",
		"/local/proxy-delay-async",
		"/local/proxy-select-async",
		"proxyMenuGeneration",
		"proxyMenuTick%3===0",
		"proxyMenuRootByGroup={}",
		"function proxyMenuRootTitle(group)",
		"function refreshProxyMenuRootTitle(group)",
		"function proxyMenuStructureSignature(data)",
		"proxyMenuStructureKey",
		"proxyPendingReconcile",
		"proxyPendingReconcile[payload.group]=true",
		"refreshProxyMenuRootTitle(payload.group)",
		"nextStructure===proxyMenuStructureKey",
		"if(oldCurrent!==newCurrent)refreshProxyMenuRootTitle(group)",
		"menuProxyDelayText(node,p.testUrl||'')",
		"function menuExtraHistory(value)",
		"function menuResolvedProxyName(name)",
		"Array.isArray(value.history)",
		"if(isFinite(x)&&x>0)return x",
	} {
		if !strings.Contains(script, marker) {
			t.Fatalf("status-menu proxy hotfix missing marker %q", marker)
		}
	}
	if strings.Contains(script, "addSymbol(root,'point.3.connected.trianglepath.dotted')") {
		t.Fatal("proxy-group root must not add a synthetic SF Symbol")
	}
	if strings.Contains(script, "Object.keys(proxyMenuRootByGroup).forEach(refreshProxyMenuRootTitle)") {
		t.Fatal("unchanged proxy snapshots must not relayout every proxy-group root")
	}
	if strings.Contains(script, "var data=get('/local/proxies',true)") ||
		strings.Contains(script, "var data=get('/local/proxy-menu-cache',true)") {
		t.Fatal("status-menu refresh must not spawn curl or synchronously fetch proxy data")
	}
}

func TestProxySelectionImmediatelyRefreshesMenuSnapshot(t *testing.T) {
	dir := t.TempDir()
	state := &appState{
		path: filepath.Join(dir, "settings.json"),
		settings: Settings{
			SelectedID: "test",
			Profiles: []Profile{{
				ID: "test", Name: "test", ManagementURL: "https://example.com",
				CoreControllerURL: "https://controller.example.com",
			}},
		},
		proxyMenuGeneration: 7,
		proxyMenuData:       []byte(`{"proxies":{"GLOBAL":{"name":"GLOBAL","type":"Selector","now":"Old","all":["Old","New"]},"Old":{"name":"Old","type":"Direct"},"New":{"name":"New","type":"Direct"}}}`),
	}

	state.applyProxyMenuSelectionSnapshot("GLOBAL", "New")

	var got struct {
		Generation uint64                    `json:"generation"`
		ProfileID  string                    `json:"_profileID"`
		Proxies    map[string]map[string]any `json:"proxies"`
	}
	if err := json.Unmarshal(state.proxyMenuResponse, &got); err != nil {
		t.Fatal(err)
	}
	if got.Generation != 8 {
		t.Fatalf("expected generation 8, got %d", got.Generation)
	}
	if got.ProfileID != "test" {
		t.Fatalf("unexpected profile id: %q", got.ProfileID)
	}
	if got.Proxies["GLOBAL"]["now"] != "New" {
		t.Fatalf("menu snapshot suffix was not refreshed: %#v", got.Proxies["GLOBAL"])
	}

	fileData, err := os.ReadFile(filepath.Join(dir, "Runtime", "proxies.json"))
	if err != nil {
		t.Fatal(err)
	}
	var disk map[string]any
	if err := json.Unmarshal(fileData, &disk); err != nil {
		t.Fatal(err)
	}
	proxies := disk["proxies"].(map[string]any)
	global := proxies["GLOBAL"].(map[string]any)
	if global["now"] != "New" {
		t.Fatalf("disk-backed status menu did not receive new suffix: %#v", global)
	}
}

func TestPortableWindowUsesUnifiedLeftRightBrandWithoutTitlebar(t *testing.T) {
	page, err := assets.ReadFile("ui/index.html")
	if err != nil {
		t.Fatal(err)
	}
	text := string(page)
	for _, marker := range []string{
		"grid-template-columns:256px minmax(0,1fr)",
		"grid-template-rows:minmax(0,1fr)",
		".brand-product{color:var(--text)",
		`class="brand-head"`,
		`class="brand-product">Mihomo Core`,
		`class="brand-title">管理面板`,
		"A just-confirmed PUT is authoritative for this group",
	} {
		if !strings.Contains(text, marker) {
			t.Fatalf("portable v1.2.5 unified window missing marker %q", marker)
		}
	}
	if strings.Contains(text, `<div class="titlebar">`) || strings.Contains(text, "--titlebar:") {
		t.Fatal("portable main window must not render a separate visual title bar")
	}
}

func TestPortableProxyPageHotfixUsesGlobalOrderAndImmediateLatencyMerge(t *testing.T) {
	page, err := assets.ReadFile("ui/index.html")
	if err != nil {
		t.Fatal(err)
	}
	text := string(page)
	for _, marker := range []string{
		"proxyData?.GLOBAL?.all",
		"Object.values(p.extra)",
		"function extraHistory(value)",
		"function resolvedProxyName(name)",
		"Array.isArray(value.history)",
		"if(Number.isFinite(v)&&v>0)return v",
		"proxyData[name].lastTestDelay=value",
		"proxyData[resolved].lastTestDelay=value",
		"if(data._stale)",
		"Controller 暂时不可达，正在显示最近一次代理数据",
		"if(proxyData?.[group])proxyData[group].now=name",
		"A just-confirmed PUT is authoritative for this group",
		"测速完成，共 '+Object.keys(delays).length",
	} {
		if !strings.Contains(text, marker) {
			t.Fatalf("portable proxy hotfix missing marker %q", marker)
		}
	}
	if strings.Contains(text, "groups=await api('/local/proxy-groups')") {
		t.Fatal("proxy page default order must not depend on Mihomo /group map iteration")
	}
}

func TestProviderOnlyLeafNodesAreMergedWithLatency(t *testing.T) {
	state := &appState{proxyDelayCache: map[string]map[string]int{}}

	proxyData := []byte(`{
		"proxies": {
			"🇭🇰 香港": {
				"name": "🇭🇰 香港",
				"type": "Selector",
				"now": "HK-Provider-01",
				"all": ["HK-Provider-01"]
			},
			"GLOBAL": {
				"name": "GLOBAL",
				"type": "Selector",
				"now": "🇭🇰 香港",
				"all": ["🇭🇰 香港"]
			}
		}
	}`)
	providerData := []byte(`{
		"providers": {
			"机场订阅": {
				"name": "机场订阅",
				"testUrl": "https://provider.example/generate_204",
				"proxies": [
					{
						"name": "HK-Provider-01",
						"type": "VLESS",
						"alive": true,
						"history": [],
						"extra": {
							"https://provider.example/generate_204": {
								"alive": true,
								"history": [
									{"time": "2026-09-11T03:00:00Z", "delay": 87}
								]
							}
						}
					}
				]
			}
		}
	}`)

	merged, err := mergeProviderProxyPayload(proxyData, providerData)
	if err != nil {
		t.Fatal(err)
	}
	decorated, err := state.decorateProxyPayload("profile-1", merged)
	if err != nil {
		t.Fatal(err)
	}

	var payload struct {
		Proxies map[string]map[string]any `json:"proxies"`
	}
	if err := json.Unmarshal(decorated, &payload); err != nil {
		t.Fatal(err)
	}

	leaf, ok := payload.Proxies["HK-Provider-01"]
	if !ok {
		t.Fatal("provider-only leaf node was not merged into /proxies payload")
	}
	if got := int(leaf["lastTestDelay"].(float64)); got != 87 {
		t.Fatalf("provider leaf latency mismatch: got %d want 87", got)
	}
	if got, _ := leaf["provider-name"].(string); got != "机场订阅" {
		t.Fatalf("provider name was not retained: %q", got)
	}
}

func TestZeroLatencyDoesNotMaskPositiveProviderLatency(t *testing.T) {
	proxy := map[string]any{
		"name": "Node-A",
		"extra": map[string]any{
			"https://global.example/204": map[string]any{
				"alive": false,
				"history": []any{
					map[string]any{"time": "2026-09-11T03:10:00Z", "delay": float64(0)},
				},
			},
			"https://provider.example/204": map[string]any{
				"alive": true,
				"history": []any{
					map[string]any{"time": "2026-09-11T03:00:00Z", "delay": float64(123)},
				},
			},
		},
	}
	delay, ok := latencyFromProxyObject(proxy)
	if !ok || delay != 123 {
		t.Fatalf("zero placeholder masked positive latency: ok=%v delay=%d", ok, delay)
	}

	state := &appState{
		proxyDelayCache: map[string]map[string]int{
			"profile-1": {"Node-A": 0},
		},
	}
	raw, _ := json.Marshal(map[string]any{"proxies": map[string]any{"Node-A": proxy}})
	decorated, err := state.decorateProxyPayload("profile-1", raw)
	if err != nil {
		t.Fatal(err)
	}
	var payload struct {
		Proxies map[string]map[string]any `json:"proxies"`
	}
	if err := json.Unmarshal(decorated, &payload); err != nil {
		t.Fatal(err)
	}
	if got := int(payload.Proxies["Node-A"]["lastTestDelay"].(float64)); got != 123 {
		t.Fatalf("explicit zero must not mask positive provider latency: got %d", got)
	}
}

func TestHandleProxiesFetchesProviderLeafNodes(t *testing.T) {
	controller := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/proxies":
			_, _ = w.Write([]byte(`{
				"proxies": {
					"Group-A": {"name":"Group-A","type":"Selector","now":"Leaf-A","all":["Leaf-A"]},
					"GLOBAL": {"name":"GLOBAL","type":"Selector","now":"Group-A","all":["Group-A"]}
				}
			}`))
		case "/providers/proxies":
			_, _ = w.Write([]byte(`{
				"providers": {
					"Provider-A": {
						"name":"Provider-A",
						"testUrl":"https://provider.example/204",
						"proxies":[{
							"name":"Leaf-A",
							"type":"VLESS",
							"alive":true,
							"extra":{
								"https://provider.example/204":{
									"alive":true,
									"history":[{"time":"2026-09-11T03:00:00Z","delay":66}]
								}
							}
						}]
					}
				}
			}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer controller.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{
			SelectedID: "test",
			Profiles: []Profile{{
				ID: "test", Name: "test",
				ManagementURL:     controller.URL,
				CoreControllerURL: controller.URL,
				AllowInsecureHTTP: true,
			}},
		},
		client:          controller.Client(),
		secretCache:     map[string]string{"test": ""},
		proxyDelayCache: map[string]map[string]int{},
	}

	rec := httptest.NewRecorder()
	state.handleProxies(rec, httptest.NewRequest(http.MethodGet, "/local/proxies", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("handleProxies failed: %d %s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), `"Leaf-A"`) ||
		!strings.Contains(rec.Body.String(), `"lastTestDelay":66`) {
		t.Fatalf("provider leaf latency missing from merged proxy payload: %s", rec.Body.String())
	}
}

func TestCloudflare1033MessageIsConcise(t *testing.T) {
	data := []byte(`{
		"title":"Error 1033: Cloudflare Tunnel error",
		"status":530,
		"detail":"The host is configured as a Cloudflare Tunnel, but Cloudflare is currently unable to reach it.",
		"error_code":1033
	}`)
	got := remoteMessage(data, nil)
	want := "Cloudflare Tunnel 暂时断开（Error 1033）。Controller 主机当前不可达，请稍后重试。"
	if got != want {
		t.Fatalf("unexpected Cloudflare message: %q", got)
	}
}

func TestRemoteRequestRetriesTransient530GET(t *testing.T) {
	attempts := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		w.Header().Set("Content-Type", "application/json")
		if attempts < 3 {
			w.WriteHeader(530)
			_, _ = w.Write([]byte(`{"title":"Error 1033: Cloudflare Tunnel error","error_code":1033}`))
			return
		}
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer server.Close()

	state := &appState{client: server.Client()}
	data, code, err := state.remoteRequest(http.MethodGet, server.URL, nil, "")
	if err != nil {
		t.Fatal(err)
	}
	if code != http.StatusOK || !strings.Contains(string(data), `"ok":true`) {
		t.Fatalf("unexpected response after retry: code=%d body=%s", code, data)
	}
	if attempts != 3 {
		t.Fatalf("expected 3 GET attempts, got %d", attempts)
	}
}

func TestTransient530UsesPersistentProxySnapshot(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(530)
		_, _ = w.Write([]byte(`{
			"title":"Error 1033: Cloudflare Tunnel error",
			"error_code":1033,
			"detail":"Cloudflare Tunnel unavailable"
		}`))
	}))
	defer server.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "MihomoCoreManager", "settings.json"),
		settings: Settings{
			SelectedID: "test",
			Profiles: []Profile{{
				ID: "test", Name: "test",
				ManagementURL:     controllerURLForTest(server.URL),
				CoreControllerURL: controllerURLForTest(server.URL),
				AllowInsecureHTTP: true,
			}},
		},
		client:          server.Client(),
		secretCache:     map[string]string{"test": ""},
		proxyDelayCache: map[string]map[string]int{},
	}

	snapshot := []byte(`{
		"ok":true,
		"_profileID":"test",
		"generation":7,
		"proxies":{
			"GLOBAL":{"name":"GLOBAL","type":"Selector","now":"Group-A","all":["Group-A"]},
			"Group-A":{"name":"Group-A","type":"Selector","now":"Leaf-A","all":["Leaf-A"]},
			"Leaf-A":{"name":"Leaf-A","type":"VLESS","lastTestDelay":77}
		}
	}`)
	state.writeProxyMenuFile(snapshot)

	data, code, err := state.fetchMergedProxyPayload()
	if err != nil {
		t.Fatalf("expected stale snapshot fallback, got error: %v", err)
	}
	if code != http.StatusOK {
		t.Fatalf("stale fallback should be local HTTP 200, got %d", code)
	}
	var payload map[string]any
	if err := json.Unmarshal(data, &payload); err != nil {
		t.Fatal(err)
	}
	if stale, _ := payload["_stale"].(bool); !stale {
		t.Fatalf("stale marker missing: %s", data)
	}
	if warning, _ := payload["_warning"].(string); !strings.Contains(warning, "最近一次") {
		t.Fatalf("stale warning missing: %s", data)
	}
	proxies, _ := payload["proxies"].(map[string]any)
	leaf, _ := proxies["Leaf-A"].(map[string]any)
	if got := int(leaf["lastTestDelay"].(float64)); got != 77 {
		t.Fatalf("cached leaf latency lost: got %d", got)
	}
}

func controllerURLForTest(raw string) string { return raw }

func TestDirectControllerPrefersControllerSecret(t *testing.T) {
	controller := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "Bearer controller-secret" {
			t.Errorf("expected controller bearer secret, got %q", got)
			http.Error(w, "bad authorization", http.StatusUnauthorized)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"mode":"rule"}`))
	}))
	defer controller.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{
			SelectedID: "test",
			Profiles: []Profile{{
				ID: "test", Name: "test", ManagementURL: controller.URL,
				CoreControllerURL: controller.URL, AllowInsecureHTTP: true,
			}},
		},
		client:                controller.Client(),
		secretCache:           map[string]string{"test": "management-secret"},
		controllerSecretCache: map[string]string{"test": "controller-secret"},
	}

	rec := httptest.NewRecorder()
	state.handleProxyMode(rec, httptest.NewRequest(http.MethodGet, "/local/proxy-mode", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"mode":"rule"`) {
		t.Fatalf("controller secret request failed: %d %s", rec.Code, rec.Body.String())
	}
}

func TestDirectControllerAllowsNoAuth(t *testing.T) {
	controller := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "" {
			t.Errorf("expected no Authorization header, got %q", got)
			http.Error(w, "unexpected authorization", http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"mode":"direct"}`))
	}))
	defer controller.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{
			SelectedID: "test",
			Profiles: []Profile{{
				ID: "test", Name: "test", ManagementURL: controller.URL,
				CoreControllerURL: controller.URL, AllowInsecureHTTP: true,
			}},
		},
		client:                controller.Client(),
		secretCache:           map[string]string{"test": ""},
		controllerSecretCache: map[string]string{"test": ""},
	}

	rec := httptest.NewRecorder()
	state.handleProxyMode(rec, httptest.NewRequest(http.MethodGet, "/local/proxy-mode", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"mode":"direct"`) {
		t.Fatalf("no-auth controller request failed: %d %s", rec.Code, rec.Body.String())
	}
}

func TestProxyControllerModeListAndSelection(t *testing.T) {
	mode := "rule"
	selected := "A"
	controller := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer secret" {
			t.Errorf("missing bearer secret: %q", r.Header.Get("Authorization"))
			http.Error(w, "missing bearer secret", http.StatusUnauthorized)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		switch {
		case r.URL.Path == "/configs" && r.Method == http.MethodGet:
			_, _ = w.Write([]byte(`{"mode":"` + mode + `"}`))
		case r.URL.Path == "/configs" && r.Method == http.MethodPatch:
			var in map[string]string
			_ = json.NewDecoder(r.Body).Decode(&in)
			mode = in["mode"]
			w.WriteHeader(http.StatusNoContent)
		case r.URL.Path == "/proxies" && r.Method == http.MethodGet:
			_, _ = w.Write([]byte(`{"proxies":{"GLOBAL":{"name":"GLOBAL","type":"Selector","now":"` + selected + `","all":["A","B"]},"A":{"name":"A","type":"Shadowsocks","alive":true},"B":{"name":"B","type":"Shadowsocks","alive":true}}}`))
		case r.URL.Path == "/proxies/GLOBAL" && r.Method == http.MethodPut:
			var in map[string]string
			_ = json.NewDecoder(r.Body).Decode(&in)
			selected = in["name"]
			w.WriteHeader(http.StatusNoContent)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer controller.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{
			SelectedID: "test",
			Profiles: []Profile{{
				ID: "test", Name: "test", ManagementURL: controller.URL,
				CoreControllerURL: controller.URL, AllowInsecureHTTP: true,
			}},
		},
		client:      controller.Client(),
		secretCache: map[string]string{"test": "secret"},
	}
	t.Cleanup(state.waitBackground)

	rec := httptest.NewRecorder()
	state.handleProxyMode(rec, httptest.NewRequest(http.MethodGet, "/local/proxy-mode", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"mode":"rule"`) {
		t.Fatalf("mode GET failed: %d %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	state.handleProxyMode(rec, httptest.NewRequest(http.MethodPost, "/local/proxy-mode", strings.NewReader(`{"mode":"global"}`)))
	if rec.Code != http.StatusOK || mode != "global" {
		t.Fatalf("mode POST failed: %d mode=%s body=%s", rec.Code, mode, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	state.handleProxies(rec, httptest.NewRequest(http.MethodGet, "/local/proxies", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"GLOBAL"`) {
		t.Fatalf("proxy list failed: %d %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	state.handleProxySelect(rec, httptest.NewRequest(http.MethodPost, "/local/proxy-select", strings.NewReader(`{"group":"GLOBAL","name":"B"}`)))
	if rec.Code != http.StatusOK || selected != "B" {
		t.Fatalf("proxy select failed: %d selected=%s body=%s", rec.Code, selected, rec.Body.String())
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

	req := httptest.NewRequest(http.MethodPost, "/local/menu-preferences", strings.NewReader(`{"showIcon":true,"showStatus":false,"showSpeed":true,"refreshIntervalMS":5000,"logLines":300}`))
	rec := httptest.NewRecorder()
	state.handleMenuPreferences(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("unexpected status: %d (%s)", rec.Code, rec.Body.String())
	}

	var got map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got["showIcon"] != true || got["showStatus"] != false || got["showSpeed"] != true || got["refreshIntervalMS"] != float64(5000) || got["logLines"] != float64(300) {
		t.Fatalf("unexpected prefs: %#v", got)
	}
	if state.refreshInterval() != 5*time.Second {
		t.Fatalf("refresh interval was not applied: %v", state.refreshInterval())
	}

	// The native menu process posts only its three booleans. That must not erase
	// the v1.3.0-compatible refresh/log preferences restored in the Web UI.
	req = httptest.NewRequest(http.MethodPost, "/local/menu-preferences", strings.NewReader(`{"showIcon":true,"showStatus":true,"showSpeed":false}`))
	rec = httptest.NewRecorder()
	state.handleMenuPreferences(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("tray-only preference update failed: %d (%s)", rec.Code, rec.Body.String())
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
	if got["showIcon"] != true || got["showStatus"] != true || got["showSpeed"] != false || got["refreshIntervalMS"] != float64(5000) || got["logLines"] != float64(300) {
		t.Fatalf("prefs did not persist in state: %#v", got)
	}
}

func TestDirectRestartPrefersMihomoCoreAPI(t *testing.T) {
	restartCalls, managementCalls := 0, 0
	controller := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/restart":
			restartCalls++
			if r.Method != http.MethodPost {
				t.Errorf("restart method = %s", r.Method)
			}
			if got := r.Header.Get("Authorization"); got != "Bearer controller-secret" {
				t.Errorf("restart Authorization = %q", got)
			}
			var body map[string]string
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Errorf("decode restart body: %v", err)
			}
			if body["path"] != "/etc/mihomo/config.yaml" || body["payload"] != "" {
				t.Errorf("unexpected restart body: %#v", body)
			}
			w.WriteHeader(http.StatusNoContent)
		case "/api/action":
			managementCalls++
			_, _ = w.Write([]byte(`{"ok":true}`))
		case "/version":
			_, _ = w.Write([]byte(`{"version":"test"}`))
		case "/connections":
			_, _ = w.Write([]byte(`{"connections":[],"uploadTotal":0,"downloadTotal":0,"memory":0}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer controller.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{SelectedID: "test", Profiles: []Profile{{
			ID: "test", Name: "test", ManagementURL: controller.URL, CoreControllerURL: controller.URL,
			ConfigPath: "/etc/mihomo/config.yaml", AllowInsecureHTTP: true,
		}}},
		client:                controller.Client(),
		secretCache:           map[string]string{"test": "management-secret"},
		controllerSecretCache: map[string]string{"test": "controller-secret"},
		proxyDelayCache:       map[string]map[string]int{},
	}
	t.Cleanup(state.waitBackground)

	rec := httptest.NewRecorder()
	state.handleAction(rec, httptest.NewRequest(http.MethodPost, "/local/action", strings.NewReader(`{"action":"restart"}`)))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"via":"controller"`) {
		t.Fatalf("direct restart failed: %d %s", rec.Code, rec.Body.String())
	}
	if restartCalls != 1 || managementCalls != 0 {
		t.Fatalf("restart=%d management=%d; expected Core API only", restartCalls, managementCalls)
	}
}

func TestRestartFallsBackToManagementWhenControllerRestartFails(t *testing.T) {
	restartCalls, managementCalls := 0, 0
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/restart":
			restartCalls++
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write([]byte(`{"message":"unsupported"}`))
		case "/api/action":
			managementCalls++
			var body map[string]string
			_ = json.NewDecoder(r.Body).Decode(&body)
			if body["action"] != "restart" {
				t.Errorf("fallback action = %q", body["action"])
			}
			_, _ = w.Write([]byte(`{"ok":true,"message":"fallback ok"}`))
		case "/version":
			_, _ = w.Write([]byte(`{"version":"test"}`))
		case "/connections":
			_, _ = w.Write([]byte(`{"connections":[],"uploadTotal":0,"downloadTotal":0,"memory":0}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer remote.Close()

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{SelectedID: "test", Profiles: []Profile{{
			ID: "test", Name: "test", ManagementURL: remote.URL, CoreControllerURL: remote.URL,
			ConfigPath: "/etc/mihomo/config.yaml", AllowInsecureHTTP: true,
		}}},
		client:                remote.Client(),
		secretCache:           map[string]string{"test": "management-secret"},
		controllerSecretCache: map[string]string{"test": "controller-secret"},
		proxyDelayCache:       map[string]map[string]int{},
	}
	t.Cleanup(state.waitBackground)

	rec := httptest.NewRecorder()
	state.handleAction(rec, httptest.NewRequest(http.MethodPost, "/local/action", strings.NewReader(`{"action":"restart"}`)))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "fallback ok") {
		t.Fatalf("management fallback failed: %d %s", rec.Code, rec.Body.String())
	}
	if restartCalls != 1 || managementCalls != 1 {
		t.Fatalf("restart=%d management=%d; expected one Core attempt then one management fallback", restartCalls, managementCalls)
	}
}

func TestEffectiveSystemdSSHTargetRequiresExplicitConfiguration(t *testing.T) {
	p := Profile{
		ManagementURL:     "http://192.168.8.202:29090",
		CoreControllerURL: "http://192.168.9.202:9090",
	}
	if got := effectiveSystemdSSHTarget(p); got != "" {
		t.Fatalf("LAN URLs must not be inferred as SSH targets, got %q", got)
	}
	p.SystemdSSHTarget = "root@mihomo.lan"
	if got := effectiveSystemdSSHTarget(p); got != "root@mihomo.lan" {
		t.Fatalf("explicit SSH target must remain authoritative, got %q", got)
	}
}

func TestControllerHTTPFallsBackThroughSSHToServerLoopback(t *testing.T) {
	oldRunner := systemSSHStdinRunner
	defer func() { systemSSHStdinRunner = oldRunner }()

	var mu sync.Mutex
	var commands []string
	systemSSHStdinRunner = func(ctx context.Context, stdin []byte, args ...string) ([]byte, error) {
		joined := strings.Join(args, " ")
		command := args[len(args)-1]
		mu.Lock()
		commands = append(commands, joined)
		mu.Unlock()
		if strings.Contains(command, "192.168.9.202:9090/proxies") {
			return []byte("curl: (7) Failed to connect"), errors.New("exit status 7")
		}
		if strings.Contains(command, "127.0.0.1:9090/proxies") {
			return []byte(`{"proxies":{}}` + "\n" + sshHTTPStatusMarker + "200"), nil
		}
		return []byte("unexpected SSH request"), errors.New("unexpected SSH request")
	}

	state := &appState{
		settings: Settings{SelectedID: "p1", Profiles: []Profile{{
			ID: "p1", Name: "test", ManagementURL: "http://192.168.8.202:29090",
			CoreControllerURL: "http://192.168.9.202:9090", SystemdSSHTarget: "root@192.168.8.202", AllowInsecureHTTP: true,
		}}},
		client: &http.Client{Transport: roundTripperFunc(func(r *http.Request) (*http.Response, error) {
			return nil, errors.New("dial tcp 192.168.9.202:9090: connect: no route to host")
		})},
		secretCache:           map[string]string{"p1": "panel-secret"},
		controllerSecretCache: map[string]string{"p1": "core-secret"},
	}
	data, code, err := state.remote(http.MethodGet, "/proxies", nil, nil, true)
	if err != nil {
		t.Fatal(err)
	}
	if code != http.StatusOK || !strings.Contains(string(data), `"proxies"`) {
		t.Fatalf("unexpected fallback response: code=%d data=%s", code, data)
	}
	mu.Lock()
	joined := strings.Join(commands, "\n")
	mu.Unlock()
	for _, want := range []string{"-- root@192.168.8.202", "192.168.9.202:9090/proxies", "127.0.0.1:9090/proxies"} {
		if !strings.Contains(joined, want) {
			t.Fatalf("SSH fallback missing %q:\n%s", want, joined)
		}
	}
}

func TestManagementEndpointsFallBackThroughSSHToServerLoopback(t *testing.T) {
	oldRunner := systemSSHStdinRunner
	defer func() { systemSSHStdinRunner = oldRunner }()

	systemSSHStdinRunner = func(ctx context.Context, stdin []byte, args ...string) ([]byte, error) {
		command := args[len(args)-1]
		if strings.Contains(command, "192.168.8.202:29090") {
			return []byte("curl: (7) Failed to connect"), errors.New("exit status 7")
		}
		switch {
		case strings.Contains(command, "127.0.0.1:29090/api/subscriptions"):
			return []byte(`{"ok":true,"subscriptions":{}}` + "\n" + sshHTTPStatusMarker + "200"), nil
		case strings.Contains(command, "127.0.0.1:29090/api/project-update/check"):
			return []byte(`{"ok":true,"updates":[]}` + "\n" + sshHTTPStatusMarker + "200"), nil
		default:
			return []byte("unexpected SSH request"), errors.New("unexpected SSH request")
		}
	}

	state := &appState{
		settings: Settings{SelectedID: "p1", Profiles: []Profile{{
			ID: "p1", Name: "test", ManagementURL: "http://192.168.8.202:29090",
			CoreControllerURL: "http://192.168.9.202:9090", SystemdSSHTarget: "root@192.168.8.202", AllowInsecureHTTP: true,
		}}},
		client: &http.Client{Transport: roundTripperFunc(func(r *http.Request) (*http.Response, error) {
			return nil, errors.New("dial tcp 192.168.8.202:29090: connect: no route to host")
		})},
		secretCache:           map[string]string{"p1": "panel-secret"},
		controllerSecretCache: map[string]string{"p1": "core-secret"},
	}

	rec := httptest.NewRecorder()
	state.handleSubscriptions(rec, httptest.NewRequest(http.MethodGet, "/local/subscriptions", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"subscriptions"`) {
		t.Fatalf("subscriptions SSH fallback failed: %d %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	state.proxy("/api/project-update/check")(rec, httptest.NewRequest(http.MethodGet, "/local/update/check", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"updates"`) {
		t.Fatalf("update-check SSH fallback failed: %d %s", rec.Code, rec.Body.String())
	}
}

func TestProxySelectFallsBackThroughSSHWhenControllerPortIsBlocked(t *testing.T) {
	oldRunner := systemSSHStdinRunner

	systemSSHStdinRunner = func(ctx context.Context, stdin []byte, args ...string) ([]byte, error) {
		command := args[len(args)-1]
		if strings.Contains(command, "192.168.9.202:9090") {
			return []byte("curl: (7) Failed to connect"), errors.New("exit status 7")
		}
		if strings.Contains(command, "127.0.0.1:9090/proxies/GLOBAL") && strings.Contains(command, "PUT") {
			if !strings.Contains(string(stdin), `"name":"HK"`) {
				t.Fatalf("proxy selection body was not streamed through SSH stdin: %s", stdin)
			}
			return []byte("\n" + sshHTTPStatusMarker + "204"), nil
		}
		if strings.Contains(command, "127.0.0.1:9090/proxies") {
			return []byte(`{"proxies":{"GLOBAL":{"name":"GLOBAL","type":"Selector","now":"HK","all":["HK"]},"HK":{"name":"HK","type":"Direct","alive":true}}}` + "\n" + sshHTTPStatusMarker + "200"), nil
		}
		if strings.Contains(command, "127.0.0.1:9090/providers/proxies") {
			return []byte(`{"providers":{}}` + "\n" + sshHTTPStatusMarker + "200"), nil
		}
		return []byte("unexpected SSH request"), errors.New("unexpected SSH request")
	}

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{SelectedID: "p1", Profiles: []Profile{{
			ID: "p1", Name: "test", ManagementURL: "http://192.168.8.202:29090",
			CoreControllerURL: "http://192.168.9.202:9090", SystemdSSHTarget: "root@192.168.8.202", AllowInsecureHTTP: true,
		}}},
		client: &http.Client{Transport: roundTripperFunc(func(r *http.Request) (*http.Response, error) {
			return nil, errors.New("dial tcp 192.168.9.202:9090: connect: no route to host")
		})},
		secretCache:           map[string]string{"p1": "panel-secret"},
		controllerSecretCache: map[string]string{"p1": "core-secret"},
		proxyDelayCache:       map[string]map[string]int{},
	}
	t.Cleanup(func() {
		state.waitBackground()
		systemSSHStdinRunner = oldRunner
	})

	rec := httptest.NewRecorder()
	state.handleProxySelect(rec, httptest.NewRequest(http.MethodPost, "/local/proxy-select", strings.NewReader(`{"group":"GLOBAL","name":"HK"}`)))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"name":"HK"`) {
		t.Fatalf("proxy-select SSH fallback failed: %d %s", rec.Code, rec.Body.String())
	}
}

func TestLogsDoNotInferSSHHostAndPreferManagementAPI(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/logs" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		_, _ = w.Write([]byte(`{"ok":true,"logs":"panel log line\\n","via":"management"}`))
	}))
	defer backend.Close()

	oldRunner := systemSSHRunner
	defer func() { systemSSHRunner = oldRunner }()
	sshCalled := false
	systemSSHRunner = func(ctx context.Context, args ...string) ([]byte, error) {
		sshCalled = true
		return nil, errors.New("SSH must not be inferred")
	}
	state := &appState{
		settings: Settings{SelectedID: "p1", Profiles: []Profile{{
			ID: "p1", Name: "test", ManagementURL: backend.URL,
			CoreControllerURL: "http://192.168.9.202:9090", AllowInsecureHTTP: true,
		}}},
		client:      backend.Client(),
		secretCache: map[string]string{"p1": "panel-secret"},
	}
	rec := httptest.NewRecorder()
	state.handleLogs(rec, httptest.NewRequest(http.MethodGet, "/local/logs?lines=100", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "panel log line") || !strings.Contains(rec.Body.String(), `"via":"management"`) {
		t.Fatalf("management logs failed: %d %s", rec.Code, rec.Body.String())
	}
	if sshCalled {
		t.Fatal("SSH must remain disabled when no explicit SSH target is configured")
	}
}

func TestSystemdSSHArgumentsUseExplicitPortAndIdentity(t *testing.T) {
	args, err := systemdSSHArgs(Profile{
		SystemdSSHTarget:    "admin@mihomo.lan",
		SystemdSSHPort:      2222,
		SystemdIdentityFile: "/tmp/id_ed25519",
	}, "systemctl status mihomo.service")
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(args, " ")
	for _, want := range []string{"BatchMode=yes", "ConnectTimeout=4", "-p 2222", "-i /tmp/id_ed25519", "-- admin@mihomo.lan", "mihomo.service"} {
		if !strings.Contains(joined, want) {
			t.Fatalf("systemd SSH args missing %q: %s", want, joined)
		}
	}
}

func TestStartPrefersSystemdBeforeManagementPanel(t *testing.T) {
	oldRunner := systemSSHRunner
	var mu sync.Mutex
	var commands []string
	systemSSHRunner = func(ctx context.Context, args ...string) ([]byte, error) {
		mu.Lock()
		commands = append(commands, args[len(args)-1])
		mu.Unlock()
		if strings.Contains(args[len(args)-1], "systemctl show mihomo.service") {
			return []byte("LoadState=loaded\nActiveState=active\nSubState=running\nUnitFileState=enabled\nMainPID=123\nFragmentPath=/etc/systemd/system/mihomo.service\n"), nil
		}
		return nil, nil
	}

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{SelectedID: "test", Profiles: []Profile{{
			ID: "test", Name: "test", ManagementURL: "http://127.0.0.1:1",
			SystemdSSHTarget: "root@mihomo.lan", SystemdSSHPort: 22, AllowInsecureHTTP: true,
		}}},
		client:      newHTTPClient(),
		secretCache: map[string]string{"test": "panel-secret"},
	}
	defer func() {
		state.waitBackground()
		systemSSHRunner = oldRunner
	}()

	rec := httptest.NewRecorder()
	state.handleAction(rec, httptest.NewRequest(http.MethodPost, "/local/action", strings.NewReader(`{"action":"start"}`)))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"via":"systemd"`) {
		t.Fatalf("start did not prefer systemd: %d %s", rec.Code, rec.Body.String())
	}
	state.waitBackground()
	mu.Lock()
	joined := strings.Join(commands, "\n")
	mu.Unlock()
	if !strings.Contains(joined, "systemctl start mihomo.service") {
		t.Fatalf("missing systemd start command: %s", joined)
	}
	if !strings.Contains(joined, "systemctl disable mihomo.service") {
		t.Fatalf("direct start must preserve v4.0.1 no-autostart policy: %s", joined)
	}
}

func TestRestartFallsBackFromControllerToManagementBeforeExplicitSSH(t *testing.T) {
	var panelActionHits atomic.Int32
	controller := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/restart", "/version":
			http.Error(w, "controller unavailable", http.StatusServiceUnavailable)
		case "/api/action":
			panelActionHits.Add(1)
			_, _ = w.Write([]byte(`{"ok":true,"message":"panel restart","via":"management"}`))
		case "/api/status":
			_, _ = w.Write([]byte(`{"ok":true,"service":{"active":true},"manager":"Core service panel"}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer controller.Close()

	oldRunner := systemSSHRunner
	defer func() { systemSSHRunner = oldRunner }()
	sshCalled := false
	systemSSHRunner = func(ctx context.Context, args ...string) ([]byte, error) {
		sshCalled = true
		return nil, errors.New("SSH must be final fallback")
	}
	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{SelectedID: "test", Profiles: []Profile{{
			ID: "test", Name: "test", CoreControllerURL: controller.URL, ManagementURL: controller.URL,
			SystemdSSHTarget: "root@mihomo.lan", SystemdSSHPort: 22, AllowInsecureHTTP: true,
		}}},
		client:                controller.Client(),
		secretCache:           map[string]string{"test": "panel-secret"},
		controllerSecretCache: map[string]string{"test": ""},
	}
	defer state.waitBackground()

	rec := httptest.NewRecorder()
	state.handleAction(rec, httptest.NewRequest(http.MethodPost, "/local/action", strings.NewReader(`{"action":"restart"}`)))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"via":"management"`) {
		t.Fatalf("restart did not use management fallback: %d %s", rec.Code, rec.Body.String())
	}
	state.waitBackground()
	if hits := panelActionHits.Load(); hits != 1 {
		t.Fatalf("expected one management action, got %d", hits)
	}
	if sshCalled {
		t.Fatal("SSH must not run when the Core service panel succeeds")
	}
}

func TestStatusFallsBackFromControllerToManagementBeforeExplicitSSH(t *testing.T) {
	var panelStatusHits atomic.Int32
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/version":
			http.Error(w, "controller unavailable", http.StatusServiceUnavailable)
		case "/api/status":
			panelStatusHits.Add(1)
			_, _ = w.Write([]byte(`{"ok":true,"service":{"active":true,"unit_file_path":"/etc/systemd/system/mihomo.service"},"versions":{"core":"v1.19.30","management_panel":"v4.0.1","metacubexd":"v1.273.1"}}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer backend.Close()

	oldRunner := systemSSHRunner
	defer func() { systemSSHRunner = oldRunner }()
	sshCalled := false
	systemSSHRunner = func(ctx context.Context, args ...string) ([]byte, error) {
		sshCalled = true
		return nil, errors.New("SSH must be final fallback")
	}
	state := &appState{
		settings: Settings{SelectedID: "test", Profiles: []Profile{{
			ID: "test", Name: "test", CoreControllerURL: backend.URL, ManagementURL: backend.URL,
			SystemdSSHTarget: "root@mihomo.lan", AllowInsecureHTTP: true,
		}}},
		client:      backend.Client(),
		secretCache: map[string]string{"test": "panel-secret"},
	}
	data, err := state.fetchStatusSnapshot(state.settings.Profiles[0])
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), `"active":true`) || !strings.Contains(string(data), `"management_panel":"v4.0.1"`) {
		t.Fatalf("unexpected management status payload: %s", data)
	}
	if panelStatusHits.Load() != 1 {
		t.Fatalf("management status should be queried once, got %d", panelStatusHits.Load())
	}
	if sshCalled {
		t.Fatal("SSH must not run when management status succeeds")
	}
}

func TestLogsPreferManagementBeforeExplicitSystemdJournal(t *testing.T) {
	var panelHits atomic.Int32
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/logs" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		panelHits.Add(1)
		_, _ = w.Write([]byte(`{"ok":true,"logs":"panel line one\\npanel line two\\n","via":"management"}`))
	}))
	defer backend.Close()

	oldRunner := systemSSHRunner
	defer func() { systemSSHRunner = oldRunner }()
	sshCalled := false
	systemSSHRunner = func(ctx context.Context, args ...string) ([]byte, error) {
		sshCalled = true
		return nil, errors.New("journalctl must be final fallback")
	}
	state := &appState{
		settings: Settings{SelectedID: "test", Profiles: []Profile{{
			ID: "test", Name: "test", ManagementURL: backend.URL,
			SystemdSSHTarget: "root@mihomo.lan", AllowInsecureHTTP: true,
		}}},
		client:      backend.Client(),
		secretCache: map[string]string{"test": "panel-secret"},
	}
	rec := httptest.NewRecorder()
	state.handleLogs(rec, httptest.NewRequest(http.MethodGet, "/local/logs?lines=100", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"via":"management"`) || !strings.Contains(rec.Body.String(), "panel line one") {
		t.Fatalf("management logs failed: %d %s", rec.Code, rec.Body.String())
	}
	if panelHits.Load() != 1 {
		t.Fatalf("management logs should be queried once, got %d", panelHits.Load())
	}
	if sshCalled {
		t.Fatal("journalctl must not run when management logs succeed")
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
	t.Cleanup(state.waitBackground)

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

func TestMenuScriptUsesCachedSnapshotNativeDragAndV128WindowLifecycle(t *testing.T) {
	script := menuScript("http://127.0.0.1:12345", "token", "/tmp/status.json")
	for _, marker := range []string{
		"function statusFromFile()",
		"_menu_updated_unix_ms",
		"missingSnapshotTicks>=4",
		"MihomoWindowDragView",
		"performWindowDragWithEvent",
		"win.releasedWhenClosed=false",
		"win.movable=true",
		"function ensureWindowUsable()",
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
		"speedHeader.title='↑  上传  '+fmtRate(lastUp)+'      ↓  下载  '+fmtRate(lastDown)",
		"proxyEndSeparator=$.NSMenuItem.separatorItem; menu.addItem(proxyEndSeparator)",
		"var index=proxyEndSeparator?menu.indexOfItem(proxyEndSeparator):menu.indexOfItem(coreRoot)",
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
	for _, marker := range []string{"WKWebView", "恢复模式：状态栏渲染已降级", "打开主窗口…", "MihomoRecoveryDragView", "performWindowDragWithEvent", "win.releasedWhenClosed=false", "win.movable=true", "show(); app.run"} {
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

func TestEmbeddedModernAppIconV131(t *testing.T) {
	b, err := assets.ReadFile("ui/app-icon-128.png")
	if err != nil {
		t.Fatal(err)
	}
	if len(b) < 1024 || len(b) < 8 || string(b[:8]) != "\x89PNG\r\n\x1a\n" {
		t.Fatalf("embedded v1.3.1 app icon is missing or invalid PNG: %d bytes", len(b))
	}
}

func TestPortableVersionV132(t *testing.T) {
	if appVersion != "1.3.3" || buildNumber != "1303" {
		t.Fatalf("unexpected portable version/build: %s/%s", appVersion, buildNumber)
	}
}

func TestPerformanceHTTPClientKeepsTLSSafetyAndConnectionReuse(t *testing.T) {
	client := newHTTPClient()
	transport, ok := client.Transport.(*http.Transport)
	if !ok {
		t.Fatalf("unexpected transport type %T", client.Transport)
	}
	if transport.DisableKeepAlives {
		t.Fatal("performance client must keep safe HTTP connection reuse enabled")
	}
	if transport.MaxIdleConnsPerHost < 8 {
		t.Fatalf("expected pooled per-host idle connections, got %d", transport.MaxIdleConnsPerHost)
	}
	if transport.TLSClientConfig != nil && transport.TLSClientConfig.InsecureSkipVerify {
		t.Fatal("performance tuning must never disable TLS certificate verification")
	}
	if transport.Proxy == nil {
		t.Fatal("backend transport must install LAN-aware proxy policy")
	}
	if transport.DialContext == nil {
		t.Fatal("backend transport must install macOS LAN resolver dialer")
	}
}

func TestHandleStatusServesSameProfileCacheWithoutWaitingForRefresh(t *testing.T) {
	state := &appState{
		settings: Settings{
			SelectedID: "p1",
			Profiles: []Profile{{
				ID: "p1", Name: "test", ManagementURL: "https://example.com",
			}},
		},
		statusData:      []byte(`{"service":{"active":true},"speed":{"up":12,"down":34}}`),
		statusProfileID: "p1",
		statusUpdatedAt: time.Now().Add(-10 * time.Second),
		statusReachable: true,
	}

	// Simulate a refresh already in progress. handleStatus must return the
	// same-profile last-good snapshot immediately instead of queuing behind it.
	state.statusFetchMu.Lock()
	defer state.statusFetchMu.Unlock()

	rec := httptest.NewRecorder()
	state.handleStatus(rec, httptest.NewRequest(http.MethodGet, "/local/status", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("expected cached status, got %d %s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), `"up":12`) || !strings.Contains(rec.Body.String(), `"down":34`) {
		t.Fatalf("cached speed snapshot was not returned: %s", rec.Body.String())
	}
}

func TestRemoteWriteIsNeverRetried(t *testing.T) {
	attempts := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		w.WriteHeader(http.StatusServiceUnavailable)
		_, _ = w.Write([]byte(`{"message":"temporary"}`))
	}))
	defer server.Close()

	state := &appState{client: server.Client()}
	_, _, err := state.remoteRequest(http.MethodPut, server.URL, []byte(`{"name":"B"}`), "")
	if err == nil {
		t.Fatal("expected write failure")
	}
	if attempts != 1 {
		t.Fatalf("mutating requests must never be retried automatically, got %d attempts", attempts)
	}
}

func TestStatusTelemetryGraceIsRecentAndBounded(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
		_, _ = w.Write([]byte(`{"message":"temporary"}`))
	}))
	defer server.Close()

	old := []byte(`{"service":{"active":true},"speed":{"up":100,"down":200}}`)
	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{
			SelectedID: "p1",
			Profiles: []Profile{{
				ID: "p1", Name: "test", ManagementURL: server.URL, AllowInsecureHTTP: true,
			}},
		},
		client:          server.Client(),
		secretCache:     map[string]string{"p1": "secret"},
		statusData:      append([]byte(nil), old...),
		statusProfileID: "p1",
		statusUpdatedAt: time.Now().Add(-time.Second),
		statusReachable: true,
	}
	state.writeStatusFile(old)

	firstGoodAt := state.statusUpdatedAt
	state.refreshStatusCache()
	if !state.statusReachable || !strings.Contains(string(state.statusData), `"up":100`) {
		t.Fatal("a single telemetry failure should preserve a very recent same-profile snapshot")
	}
	if !state.statusUpdatedAt.Equal(firstGoodAt) {
		t.Fatal("grace must retain the original last-good timestamp so it cannot extend indefinitely")
	}
	if _, err := os.Stat(state.statusFilePath()); err != nil {
		t.Fatalf("recent last-good tray snapshot should remain during the bounded grace: %v", err)
	}

	state.statusUpdatedAt = time.Now().Add(-5 * time.Second)
	state.refreshStatusCache()
	if state.statusReachable || len(state.statusData) != 0 {
		t.Fatal("telemetry grace must expire after a few seconds of continuous failure")
	}
	if _, err := os.Stat(state.statusFilePath()); !os.IsNotExist(err) {
		t.Fatalf("expired telemetry snapshot should be removed, err=%v", err)
	}
}

func TestNormalizeControllerPreservesReverseProxyPrefixAndStripsUICaseInsensitive(t *testing.T) {
	got, err := normalizedControllerString("https://example.test/mihomo/Ui/#/setup", false)
	if err != nil {
		t.Fatal(err)
	}
	if got != "https://example.test/mihomo" {
		t.Fatalf("unexpected normalized controller URL: %q", got)
	}

	got, err = normalizedControllerString("http://192.168.8.2:9090/prefix/ui/dashboard", true)
	if err != nil {
		t.Fatal(err)
	}
	if got != "http://192.168.8.2:9090/prefix" {
		t.Fatalf("explicit controller port/prefix not preserved: %q", got)
	}
}

func TestNormalizeManagementDeploymentEndpointPreservesPrefixAndPort(t *testing.T) {
	got, err := normalizedManagementString("http://192.168.8.2:29090/admin/api/status?x=1#frag", true)
	if err != nil {
		t.Fatal(err)
	}
	if got != "http://192.168.8.2:29090/admin" {
		t.Fatalf("unexpected normalized management URL: %q", got)
	}

	got, err = normalizedManagementString("https://panel.example.test/base/api/project-update/check", false)
	if err != nil {
		t.Fatal(err)
	}
	if got != "https://panel.example.test/base" {
		t.Fatalf("management reverse-proxy prefix was not preserved: %q", got)
	}
}

func TestEnrichStatusSpeedFromControllerTotals(t *testing.T) {
	previous := []byte(`{"ok":true,"totals":{"up":1000,"down":2000}}`)
	current := []byte(`{"ok":true,"totals":{"up":1300,"down":2600}}`)
	before := time.Unix(100, 0)
	after := before.Add(2 * time.Second)
	got := enrichStatusSpeed(current, previous, before, after)
	var payload map[string]any
	if err := json.Unmarshal(got, &payload); err != nil {
		t.Fatal(err)
	}
	speed, ok := payload["speed"].(map[string]any)
	if !ok {
		t.Fatalf("speed missing from enriched payload: %s", got)
	}
	if speed["up"].(float64) != 150 || speed["down"].(float64) != 300 {
		t.Fatalf("unexpected speed: %#v", speed)
	}
}

func TestControllerStatusEnrichesPanelVersionsAndSharesControllerSecret(t *testing.T) {
	var panelHits atomic.Int32
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/version":
			if got := r.Header.Get("Authorization"); got != "Bearer core-secret" {
				http.Error(w, "bad controller auth", http.StatusUnauthorized)
				return
			}
			_, _ = w.Write([]byte(`{"version":"v1.19.30"}`))
		case "/connections":
			_, _ = w.Write([]byte(`{"uploadTotal":11,"downloadTotal":22,"memory":333,"connections":[]}`))
		case "/api/status":
			panelHits.Add(1)
			if got := r.Header.Get("Authorization"); got != "Bearer core-secret" {
				http.Error(w, "management did not reuse Controller Secret", http.StatusUnauthorized)
				return
			}
			_, _ = w.Write([]byte(`{"ok":true,"service":{"manager":"systemd","active":true,"enabled":false,"pid":456,"unit_file_path":"/etc/systemd/system/mihomo.service"},"versions":{"core":"v0.0.0-stale","management_panel":"v4.0.1","metacubexd":"v1.273.1"},"metacubexd":{"port":29091,"url":"http://192.168.8.202:29091"}}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer backend.Close()

	state := &appState{
		settings: Settings{SelectedID: "test", Profiles: []Profile{{
			ID: "test", Name: "test", CoreControllerURL: backend.URL, ManagementURL: backend.URL,
			AllowInsecureHTTP: true,
		}}},
		client:                      backend.Client(),
		secretCache:                 map[string]string{"test": ""},
		controllerSecretCache:       map[string]string{"test": "core-secret"},
		managementMetadataData:      nil,
		managementMetadataProfileID: "",
	}
	data, err := state.fetchStatusSnapshot(state.settings.Profiles[0])
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{`"core":"v1.19.30"`, `"management_panel":"v4.0.1"`, `"metacubexd":"v1.273.1"`, `"pid":456`} {
		if !strings.Contains(text, want) {
			t.Fatalf("missing %s in enriched status: %s", want, text)
		}
	}
	if strings.Contains(text, `"core":"v0.0.0-stale"`) {
		t.Fatalf("management metadata must not override authoritative Controller core version: %s", text)
	}
	if panelHits.Load() != 1 {
		t.Fatalf("expected one management metadata request, got %d", panelHits.Load())
	}
}

func TestDeploymentAwareURLNormalizationKeepsPortsPrefixesAndSetup(t *testing.T) {
	controller, err := normalizedControllerString("192.168.8.202:9090/rev/Ui/#/proxies", true)
	if err != nil {
		t.Fatal(err)
	}
	if controller != "http://192.168.8.202:9090/rev" {
		t.Fatalf("unexpected LAN controller normalization: %q", controller)
	}
	controllerAPI, err := normalizedControllerString("https://core.example.test/rev/version?x=1", false)
	if err != nil || controllerAPI != "https://core.example.test/rev" {
		t.Fatalf("controller API suffix was not restored to root: %q err=%v", controllerAPI, err)
	}
	management, err := normalizedManagementString("192.168.8.202:29090/rev/api/login", true)
	if err != nil || management != "http://192.168.8.202:29090/rev" {
		t.Fatalf("unexpected LAN management normalization: %q err=%v", management, err)
	}
	publicManagement, err := normalizedManagementString("mihomo.kkr.cc/api", false)
	if err != nil || publicManagement != "https://mihomo.kkr.cc" {
		t.Fatalf("public management should infer https and strip /api: %q err=%v", publicManagement, err)
	}
	xd, err := normalizedMetaCubeXDString("192.168.8.202:29091/setup?backend=x#route", true)
	if err != nil {
		t.Fatal(err)
	}
	if xd != "http://192.168.8.202:29091/setup?backend=x#route" {
		t.Fatalf("MetaCubeXD setup/prefix must be preserved: %q", xd)
	}
}

func TestResolvedMetaCubeXDUsesReportedLANPortBeforePublicURLWithoutGuessing(t *testing.T) {
	profile := Profile{
		ID: "p", ManagementURL: "http://192.168.8.202:29090", MetaCubeXDURL: "https://metacubexd.kkr.cc",
		AllowInsecureHTTP: true,
	}
	metadata := []byte(`{"ok":true,"service":{"active":true},"metacubexd":{"port":29091,"url":"https://metacubexd.kkr.cc"}}`)
	state := &appState{
		settings:                    Settings{SelectedID: "p", Profiles: []Profile{profile}},
		secretCache:                 map[string]string{"p": "secret"},
		managementMetadataData:      metadata,
		managementMetadataProfileID: "p",
		managementMetadataUpdatedAt: time.Now(),
	}
	got := state.resolvedMetaCubeXDURL(profile)
	if got != "http://192.168.8.202:29091" {
		t.Fatalf("LAN Management + reported XD port should beat public URL: %q", got)
	}

	// No Management metadata means no synthetic :29091; the explicit public URL
	// remains the backup instead of guessing a business port.
	state.managementMetadataData = nil
	profile.ManagementURL = ""
	got = state.resolvedMetaCubeXDURL(profile)
	if got != "https://metacubexd.kkr.cc" {
		t.Fatalf("MetaCubeXD must not invent a port without deployment metadata: %q", got)
	}
}

func TestEndpointNormalizationRejectsWildcardListenerAddresses(t *testing.T) {
	for _, raw := range []string{"http://0.0.0.0:9090/ui", "http://[::]:29090/api/status"} {
		if _, err := normalizeBase(raw, true); err == nil || !strings.Contains(err.Error(), "监听地址") {
			t.Fatalf("wildcard listener must not be accepted as a client destination: %q err=%v", raw, err)
		}
	}
}

func TestReloadFallsBackToManagementBeforeExplicitSystemd(t *testing.T) {
	var panelActions atomic.Int32
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/configs":
			http.Error(w, "controller unavailable", http.StatusServiceUnavailable)
		case "/api/action":
			panelActions.Add(1)
			var in map[string]string
			_ = json.NewDecoder(r.Body).Decode(&in)
			if in["action"] != "reload" {
				t.Fatalf("unexpected panel action: %#v", in)
			}
			_, _ = w.Write([]byte(`{"ok":true,"message":"reloaded","via":"management"}`))
		case "/api/status":
			_, _ = w.Write([]byte(`{"ok":true,"service":{"active":true}}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer backend.Close()

	oldRunner := systemSSHRunner
	defer func() { systemSSHRunner = oldRunner }()
	sshCalled := false
	systemSSHRunner = func(ctx context.Context, args ...string) ([]byte, error) {
		sshCalled = true
		return nil, errors.New("SSH reload must be final fallback")
	}

	state := &appState{
		path: filepath.Join(t.TempDir(), "settings.json"),
		settings: Settings{SelectedID: "p", Profiles: []Profile{{
			ID: "p", Name: "test", CoreControllerURL: backend.URL, ManagementURL: backend.URL,
			SystemdSSHTarget: "root@mihomo.lan", AllowInsecureHTTP: true,
		}}},
		client:                backend.Client(),
		secretCache:           map[string]string{"p": "secret"},
		controllerSecretCache: map[string]string{"p": "secret"},
	}
	rec := httptest.NewRecorder()
	state.handleReload(rec, httptest.NewRequest(http.MethodPost, "/local/reload-config", nil))
	state.waitBackground()
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "reloaded") {
		t.Fatalf("reload did not reach Management fallback: %d %s", rec.Code, rec.Body.String())
	}
	if panelActions.Load() != 1 {
		t.Fatalf("expected one Management reload fallback, got %d", panelActions.Load())
	}
	if sshCalled {
		t.Fatal("systemd reload must not run when Management API succeeds")
	}
}

func TestManagementKeychainServiceMigrationOrderV132(t *testing.T) {
	got := managementKeychainServices()
	want := []string{
		"cc.kkr.MihomoManager.profile-secret",
		"cc.kkr.MihomoManager",
		"cc.kkr.MihomoCoreManager.profile-secret",
		"cc.kkr.MihomoCoreManager",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected management Keychain service migration order: %#v", got)
	}
}

func TestManagementSecretFallsBackSymmetrically(t *testing.T) {
	state := &appState{
		secretCache:           map[string]string{"p": ""},
		controllerSecretCache: map[string]string{"p": "controller-only"},
	}
	if got := state.managementSecretFor("p"); got != "controller-only" {
		t.Fatalf("management did not reuse Controller Secret: %q", got)
	}
	state.secretCache["p"] = "management-only"
	state.controllerSecretCache["p"] = ""
	if got := state.controllerSecret(Profile{ID: "p"}); got != "management-only" {
		t.Fatalf("controller did not reuse Management Secret: %q", got)
	}
}
