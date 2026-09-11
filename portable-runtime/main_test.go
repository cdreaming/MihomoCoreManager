package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
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
				t.Fatalf("unexpected timeout: %s", r.URL.RawQuery)
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
	if strings.Contains(script, "var data=get('/local/proxies',true)") ||
		strings.Contains(script, "var data=get('/local/proxy-menu-cache',true)") {
		t.Fatal("status-menu refresh must not spawn curl or synchronously fetch proxy data")
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
			t.Fatalf("expected controller bearer secret, got %q", got)
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
			t.Fatalf("expected no Authorization header, got %q", got)
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
			t.Fatalf("missing bearer secret: %q", r.Header.Get("Authorization"))
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

func TestPortableVersionV124(t *testing.T) {
	if appVersion != "1.2.4" || buildNumber != "124" {
		t.Fatalf("unexpected portable version/build: %s/%s", appVersion, buildNumber)
	}
}
