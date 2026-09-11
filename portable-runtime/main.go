package main

import (
	"crypto/rand"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	appVersion                = "1.2.5"
	buildNumber               = "125"
	keychainService           = "cc.kkr.MihomoCoreManager"
	controllerKeychainService = "cc.kkr.MihomoCoreManager.controller-secret"
)

//go:embed ui/index.html
var assets embed.FS

type Profile struct {
	ID                       string `json:"id"`
	Name                     string `json:"name"`
	ManagementURL            string `json:"managementURL"`
	CoreControllerURL        string `json:"coreControllerURL"`
	ConfigPath               string `json:"configPath"`
	MetaCubeXDURL            string `json:"metaCubeXDURL"`
	AllowInsecureHTTP        bool   `json:"allowInsecureHTTP"`
	PreserveSettingsOnUpdate bool   `json:"preserveSettingsOnUpdate"`
}

type MenuPreferences struct {
	ShowIcon   bool `json:"showIcon"`
	ShowStatus bool `json:"showStatus"`
	ShowSpeed  bool `json:"showSpeed"`
}

type Settings struct {
	SelectedID      string           `json:"selectedID"`
	Profiles        []Profile        `json:"profiles"`
	MenuPreferences *MenuPreferences `json:"menuPreferences,omitempty"`
}

type appState struct {
	mu       sync.RWMutex
	settings Settings
	path     string
	token    string
	server   *http.Server
	done     chan struct{}
	doneOnce sync.Once

	client *http.Client

	secretMu    sync.RWMutex
	secretCache map[string]string

	controllerSecretMu    sync.RWMutex
	controllerSecretCache map[string]string

	proxyDelayMu    sync.RWMutex
	proxyDelayCache map[string]map[string]int

	proxyMenuMu         sync.RWMutex
	proxyMenuFetchMu    sync.Mutex
	proxyMenuData       []byte
	proxyMenuResponse   []byte
	proxyMenuProfileID  string
	proxyMenuGeneration uint64
	proxyMenuUpdatedAt  time.Time
	proxyMenuErr        string

	statusMu        sync.RWMutex
	statusFetchMu   sync.Mutex
	statusData      []byte
	statusProfileID string
	statusUpdatedAt time.Time
	statusErr       string
	statusReachable bool
}

func defaultProfile() Profile {
	return Profile{
		ID: newID(), Name: "默认服务器",
		ManagementURL:            "https://mihomo.kkr.cc",
		CoreControllerURL:        "https://mihomocore.kkr.cc",
		ConfigPath:               "/etc/mihomo/config.yaml",
		MetaCubeXDURL:            "https://metacubexd.kkr.cc",
		PreserveSettingsOnUpdate: true,
	}
}

func newID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	s := hex.EncodeToString(b)
	return s[0:8] + "-" + s[8:12] + "-" + s[12:16] + "-" + s[16:20] + "-" + s[20:]
}

func newToken() string {
	b := make([]byte, 24)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func configPath() string {
	d, err := os.UserConfigDir()
	if err != nil {
		d = filepath.Join(os.Getenv("HOME"), "Library", "Application Support")
	}
	return filepath.Join(d, "MihomoCoreManager", "settings.json")
}

func loadState() *appState {
	s := &appState{
		path:            configPath(),
		token:           newToken(),
		done:            make(chan struct{}),
		client:          &http.Client{Timeout: 45 * time.Second},
		secretCache:     make(map[string]string),
		proxyDelayCache: make(map[string]map[string]int),
	}
	b, err := os.ReadFile(s.path)
	hadShowIconPreference := false
	if err == nil {
		hadShowIconPreference = strings.Contains(string(b), `"showIcon"`)
		_ = json.Unmarshal(b, &s.settings)
	}
	if len(s.settings.Profiles) == 0 {
		p := defaultProfile()
		s.settings.Profiles = []Profile{p}
		s.settings.SelectedID = p.ID
		_ = s.saveLocked()
	}
	if s.settings.SelectedID == "" {
		s.settings.SelectedID = s.settings.Profiles[0].ID
	}
	if s.settings.MenuPreferences == nil {
		s.settings.MenuPreferences = &MenuPreferences{ShowIcon: true, ShowStatus: true, ShowSpeed: true}
		_ = s.saveLocked()
	} else if !hadShowIconPreference {
		// v1.0.8 and earlier did not persist an icon preference. Preserve the
		// historical visible icon when upgrading instead of silently hiding it.
		s.settings.MenuPreferences.ShowIcon = true
		_ = s.saveLocked()
	}
	return s
}

func (s *appState) saveLocked() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(s.settings, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, b, 0600)
}

func (s *appState) current() (Profile, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, p := range s.settings.Profiles {
		if p.ID == s.settings.SelectedID {
			return p, nil
		}
	}
	if len(s.settings.Profiles) > 0 {
		return s.settings.Profiles[0], nil
	}
	return Profile{}, errors.New("尚未配置服务器")
}

func keychainGetWithService(id, service string) string {
	if runtime.GOOS != "darwin" {
		return ""
	}
	out, err := exec.Command("/usr/bin/security", "find-generic-password", "-a", id, "-s", service, "-w").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func keychainSetWithService(id, secret, service string) error {
	if runtime.GOOS != "darwin" {
		return nil
	}
	if secret == "" {
		_ = exec.Command("/usr/bin/security", "delete-generic-password", "-a", id, "-s", service).Run()
		return nil
	}
	return exec.Command("/usr/bin/security", "add-generic-password", "-U", "-a", id, "-s", service, "-w", secret).Run()
}

func keychainDeleteWithService(id, service string) {
	if runtime.GOOS == "darwin" {
		_ = exec.Command("/usr/bin/security", "delete-generic-password", "-a", id, "-s", service).Run()
	}
}

func keychainGet(id string) string {
	return keychainGetWithService(id, keychainService)
}

func keychainSet(id, secret string) error {
	return keychainSetWithService(id, secret, keychainService)
}

func keychainDelete(id string) {
	keychainDeleteWithService(id, keychainService)
}

func controllerKeychainGet(id string) string {
	return keychainGetWithService(id, controllerKeychainService)
}

func controllerKeychainSet(id, secret string) error {
	return keychainSetWithService(id, secret, controllerKeychainService)
}

func controllerKeychainDelete(id string) {
	keychainDeleteWithService(id, controllerKeychainService)
}

func (s *appState) secretFor(id string) string {
	s.secretMu.RLock()
	secret, ok := s.secretCache[id]
	s.secretMu.RUnlock()
	if ok {
		return secret
	}
	secret = keychainGet(id)
	s.secretMu.Lock()
	s.secretCache[id] = secret
	s.secretMu.Unlock()
	return secret
}

func (s *appState) cacheSecret(id, secret string) {
	s.secretMu.Lock()
	s.secretCache[id] = secret
	s.secretMu.Unlock()
}

func (s *appState) forgetSecret(id string) {
	s.secretMu.Lock()
	delete(s.secretCache, id)
	s.secretMu.Unlock()
}

func (s *appState) controllerSecretFor(id string) string {
	s.controllerSecretMu.RLock()
	secret, ok := s.controllerSecretCache[id]
	s.controllerSecretMu.RUnlock()
	if ok {
		return secret
	}
	secret = controllerKeychainGet(id)
	s.controllerSecretMu.Lock()
	if s.controllerSecretCache == nil {
		s.controllerSecretCache = make(map[string]string)
	}
	s.controllerSecretCache[id] = secret
	s.controllerSecretMu.Unlock()
	return secret
}

func (s *appState) cacheControllerSecret(id, secret string) {
	s.controllerSecretMu.Lock()
	if s.controllerSecretCache == nil {
		s.controllerSecretCache = make(map[string]string)
	}
	s.controllerSecretCache[id] = secret
	s.controllerSecretMu.Unlock()
}

func (s *appState) forgetControllerSecret(id string) {
	s.controllerSecretMu.Lock()
	delete(s.controllerSecretCache, id)
	s.controllerSecretMu.Unlock()
}

func (s *appState) cacheProxyDelays(profileID string, delays map[string]int) {
	s.proxyDelayMu.Lock()
	defer s.proxyDelayMu.Unlock()
	if s.proxyDelayCache == nil {
		s.proxyDelayCache = make(map[string]map[string]int)
	}
	if s.proxyDelayCache[profileID] == nil {
		s.proxyDelayCache[profileID] = make(map[string]int)
	}
	for name, delay := range delays {
		s.proxyDelayCache[profileID][name] = delay
	}
}

func (s *appState) proxyDelaySnapshot(profileID string) map[string]int {
	s.proxyDelayMu.RLock()
	defer s.proxyDelayMu.RUnlock()
	src := s.proxyDelayCache[profileID]
	out := make(map[string]int, len(src))
	for name, delay := range src {
		out[name] = delay
	}
	return out
}

func resolveProxyNameFromMap(proxies map[string]any, name string) string {
	current := strings.TrimSpace(name)
	if current == "" {
		return current
	}
	visited := make(map[string]bool)
	for {
		raw, ok := proxies[current]
		if !ok {
			return current
		}
		proxy, ok := raw.(map[string]any)
		if !ok {
			return current
		}
		next, _ := proxy["now"].(string)
		next = strings.TrimSpace(next)
		if next == "" || next == current || visited[current] {
			return current
		}
		if _, exists := proxies[next]; !exists {
			return current
		}
		visited[current] = true
		current = next
	}
}

func (s *appState) resolveProxyNameFromCachedMenu(name string) string {
	s.proxyMenuMu.RLock()
	data := append([]byte(nil), s.proxyMenuData...)
	s.proxyMenuMu.RUnlock()
	if len(data) == 0 {
		return strings.TrimSpace(name)
	}
	var payload map[string]any
	if json.Unmarshal(data, &payload) != nil {
		return strings.TrimSpace(name)
	}
	proxies, _ := payload["proxies"].(map[string]any)
	return resolveProxyNameFromMap(proxies, name)
}

func (s *appState) controllerSecret(profile Profile) string {
	secret := s.controllerSecretFor(profile.ID)
	if secret == "" {
		secret = s.secretFor(profile.ID)
	}
	return secret
}

func intFromJSONValue(value any) (int, bool) {
	switch v := value.(type) {
	case float64:
		return int(v), true
	case float32:
		return int(v), true
	case int:
		return v, true
	case int64:
		return int(v), true
	case json.Number:
		n, err := v.Int64()
		return int(n), err == nil
	case string:
		n, err := strconv.Atoi(strings.TrimSpace(v))
		return n, err == nil
	default:
		return 0, false
	}
}

func latestDelayFromSamples(raw any) (delay int, stamp string, found bool) {
	samples, isArray := raw.([]any)
	if !isArray || len(samples) == 0 {
		return 0, "", false
	}
	for _, item := range samples {
		sample, isMap := item.(map[string]any)
		if !isMap {
			continue
		}
		d, hasDelay := intFromJSONValue(sample["delay"])
		if !hasDelay {
			continue
		}
		t, _ := sample["time"].(string)
		if !found || t >= stamp {
			delay, stamp, found = d, t, true
		}
	}
	return
}

func latencyFromExtraValue(raw any) (delay int, stamp string, found bool) {
	// Current Mihomo uses:
	// extra[url] = {"alive": true, "history": [{time, delay}, ...]}
	// Keep compatibility with older/third-party implementations that may expose
	// the history array directly.
	if extra, ok := raw.(map[string]any); ok {
		return latestDelayFromSamples(extra["history"])
	}
	return latestDelayFromSamples(raw)
}

func latencyFromProxyObject(proxy map[string]any) (int, bool) {
	// Match MetaCubeXD's current semantics: delay==0 means NOT_CONNECTED for a
	// particular test URL. It must not hide a successful (>0) reading under
	// another URL. When several positive readings exist, choose the newest one
	// so Go map iteration order never affects the displayed latency.
	var positiveDelay int
	var positiveStamp string
	var hasPositive bool
	var fallbackDelay int
	var fallbackStamp string
	var hasFallback bool

	consider := func(d int, stamp string) {
		if d > 0 {
			if !hasPositive || stamp >= positiveStamp {
				positiveDelay, positiveStamp, hasPositive = d, stamp, true
			}
			return
		}
		if !hasFallback || stamp >= fallbackStamp {
			fallbackDelay, fallbackStamp, hasFallback = d, stamp, true
		}
	}

	if rawExtra, ok := proxy["extra"].(map[string]any); ok {
		for _, rawValue := range rawExtra {
			if d, stamp, has := latencyFromExtraValue(rawValue); has {
				consider(d, stamp)
			}
		}
	}

	if d, stamp, has := latestDelayFromSamples(proxy["history"]); has {
		consider(d, stamp)
	}

	if hasPositive {
		return positiveDelay, true
	}
	return fallbackDelay, hasFallback
}

func mergeProviderProxyPayload(proxyData, providerData []byte) ([]byte, error) {
	var payload map[string]any
	if err := json.Unmarshal(proxyData, &payload); err != nil {
		return nil, err
	}
	proxies, ok := payload["proxies"].(map[string]any)
	if !ok {
		return nil, errors.New("Controller /proxies 响应缺少 proxies")
	}

	if len(providerData) == 0 {
		return json.Marshal(payload)
	}

	var providerPayload map[string]any
	if err := json.Unmarshal(providerData, &providerPayload); err != nil {
		return json.Marshal(payload)
	}
	providers, _ := providerPayload["providers"].(map[string]any)

	for providerName, rawProvider := range providers {
		provider, ok := rawProvider.(map[string]any)
		if !ok {
			continue
		}

		// MetaCubeXD fills a group test URL from its matching provider when the
		// group object omits testUrl.
		if rawGroup, exists := proxies[providerName]; exists {
			if group, ok := rawGroup.(map[string]any); ok {
				testURL, _ := group["testUrl"].(string)
				if strings.TrimSpace(testURL) == "" {
					if inherited, _ := provider["testUrl"].(string); inherited != "" {
						group["testUrl"] = inherited
					}
				}
				if _, exists := group["expectedStatus"]; !exists {
					if expected, ok := provider["expectedStatus"]; ok {
						group["expectedStatus"] = expected
					}
				}
			}
		}

		nodes, _ := provider["proxies"].([]any)
		for _, rawNode := range nodes {
			node, ok := rawNode.(map[string]any)
			if !ok {
				continue
			}
			name, _ := node["name"].(string)
			name = strings.TrimSpace(name)
			if name == "" {
				continue
			}
			if _, exists := proxies[name]; exists {
				continue
			}

			// Provider-only leaf nodes are the important case: a group can list
			// them in `all` even though /proxies has no object for that name.
			copyNode := make(map[string]any, len(node)+1)
			for key, value := range node {
				copyNode[key] = value
			}
			copyNode["provider-name"] = providerName
			proxies[name] = copyNode
		}
	}
	return json.Marshal(payload)
}

func (s *appState) fetchMergedProxyPayloadFresh() ([]byte, int, error) {
	profile, err := s.current()
	if err != nil {
		return nil, 0, err
	}

	proxyData, code, err := s.remote(http.MethodGet, "/proxies", nil, nil, true)
	if err != nil {
		return nil, code, err
	}

	// Provider details are best-effort for backward compatibility, but current
	// Mihomo + MetaCubeXD depend on them to populate provider-only leaf nodes.
	providerData, _, providerErr := s.remote(http.MethodGet, "/providers/proxies", nil, nil, true)
	if providerErr == nil {
		if merged, mergeErr := mergeProviderProxyPayload(proxyData, providerData); mergeErr == nil {
			proxyData = merged
		}
	}

	decorated, decorateErr := s.decorateProxyPayload(profile.ID, proxyData)
	if decorateErr == nil {
		proxyData = decorated
	}
	return proxyData, code, nil
}

func (s *appState) staleProxyPayload(profileID string, reason error) ([]byte, bool) {
	// First prefer the in-memory snapshot because it is guaranteed to belong to
	// the currently selected profile when proxyMenuProfileID matches.
	s.proxyMenuMu.RLock()
	memoryProfileID := s.proxyMenuProfileID
	memoryData := append([]byte(nil), s.proxyMenuData...)
	s.proxyMenuMu.RUnlock()

	var payload map[string]any
	if memoryProfileID == profileID && len(memoryData) > 0 && json.Unmarshal(memoryData, &payload) == nil {
		payload["_stale"] = true
		payload["_warning"] = "Controller 暂时不可达，正在显示最近一次成功的代理数据。"
		if reason != nil {
			payload["_staleReason"] = reason.Error()
		}
		if encoded, err := json.Marshal(payload); err == nil {
			return encoded, true
		}
	}

	// The portable tray snapshot survives transient tunnel outages and process
	// restarts. Reuse it only when the embedded profile ID matches.
	fileData, err := os.ReadFile(s.proxyMenuFilePath())
	if err != nil || len(fileData) == 0 {
		return nil, false
	}
	payload = nil
	if json.Unmarshal(fileData, &payload) != nil {
		return nil, false
	}
	snapshotProfileID, _ := payload["_profileID"].(string)
	if snapshotProfileID != profileID {
		return nil, false
	}
	payload["_stale"] = true
	payload["_warning"] = "Controller 暂时不可达，正在显示最近一次成功的代理数据。"
	if reason != nil {
		payload["_staleReason"] = reason.Error()
	}
	if encoded, err := json.Marshal(payload); err == nil {
		return encoded, true
	}
	return nil, false
}

func (s *appState) fetchMergedProxyPayload() ([]byte, int, error) {
	profile, err := s.current()
	if err != nil {
		return nil, 0, err
	}

	data, code, err := s.fetchMergedProxyPayloadFresh()
	if err == nil {
		return data, code, nil
	}

	// A temporary Cloudflare/Tunnel/gateway failure should not blank the whole
	// proxy page if we already have a known-good snapshot.
	if isTransientGatewayStatus(code) || code == 0 {
		if stale, ok := s.staleProxyPayload(profile.ID, err); ok {
			return stale, http.StatusOK, nil
		}
	}
	return nil, code, err
}

func (s *appState) decorateProxyPayload(profileID string, data []byte) ([]byte, error) {
	var payload map[string]any
	if err := json.Unmarshal(data, &payload); err != nil {
		return nil, err
	}
	proxies, ok := payload["proxies"].(map[string]any)
	if !ok {
		return nil, errors.New("Controller /proxies 响应缺少 proxies")
	}

	explicit := s.proxyDelaySnapshot(profileID)
	for name, raw := range proxies {
		proxy, ok := raw.(map[string]any)
		if !ok {
			continue
		}
		if delay, exists := explicit[name]; exists && delay > 0 {
			proxy["lastTestDelay"] = delay
			continue
		}
		if delay, exists := latencyFromProxyObject(proxy); exists && delay > 0 {
			proxy["lastTestDelay"] = delay
			continue
		}
		if delay, exists := explicit[name]; exists {
			proxy["lastTestDelay"] = delay
			continue
		}
		if delay, exists := latencyFromProxyObject(proxy); exists {
			// Normalize Mihomo history/extra into one display field so both the
			// Web UI and status-bar JXA show latency consistently.
			proxy["lastTestDelay"] = delay
		}
	}
	return json.Marshal(payload)
}

func (s *appState) invalidateProxyMenuCache() {
	s.proxyMenuMu.Lock()
	s.proxyMenuData = nil
	s.proxyMenuResponse = nil
	s.proxyMenuProfileID = ""
	s.proxyMenuUpdatedAt = time.Time{}
	s.proxyMenuErr = ""
	s.proxyMenuGeneration++
	s.proxyMenuMu.Unlock()
	s.clearProxyMenuFile()
}

func (s *appState) proxyMenuFilePath() string {
	return filepath.Join(filepath.Dir(s.path), "Runtime", "proxies.json")
}

func (s *appState) writeProxyMenuFile(data []byte) {
	if len(data) == 0 {
		return
	}
	path := s.proxyMenuFilePath()
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0600); err == nil {
		_ = os.Rename(tmp, path)
	}
}

func (s *appState) clearProxyMenuFile() {
	_ = os.Remove(s.proxyMenuFilePath())
}

func (s *appState) refreshProxyMenuCache() {
	s.proxyMenuFetchMu.Lock()
	defer s.proxyMenuFetchMu.Unlock()

	profile, err := s.current()
	if err != nil {
		return
	}
	decorated, _, err := s.fetchMergedProxyPayloadFresh()
	if err != nil {
		s.proxyMenuMu.Lock()
		s.proxyMenuErr = err.Error()
		s.proxyMenuUpdatedAt = time.Now()
		s.proxyMenuMu.Unlock()
		return
	}

	s.proxyMenuMu.Lock()
	changed := s.proxyMenuProfileID != profile.ID || string(s.proxyMenuData) != string(decorated)
	if changed {
		s.proxyMenuGeneration++
	}
	s.proxyMenuData = append(s.proxyMenuData[:0], decorated...)
	s.proxyMenuProfileID = profile.ID
	s.proxyMenuUpdatedAt = time.Now()
	s.proxyMenuErr = ""

	var responseCopy []byte
	var payload map[string]any
	if json.Unmarshal(decorated, &payload) == nil {
		payload["ok"] = true
		payload["generation"] = s.proxyMenuGeneration
		payload["_profileID"] = profile.ID
		payload["_snapshot_unix_ms"] = time.Now().UnixMilli()
		if encoded, encodeErr := json.Marshal(payload); encodeErr == nil {
			s.proxyMenuResponse = append(s.proxyMenuResponse[:0], encoded...)
			responseCopy = append(responseCopy, encoded...)
		}
	}
	s.proxyMenuMu.Unlock()
	s.writeProxyMenuFile(responseCopy)
}

func (s *appState) startProxyMenuPoller() {
	go func() {
		s.refreshProxyMenuCache()
		ticker := time.NewTicker(4 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				s.refreshProxyMenuCache()
			case <-s.done:
				return
			}
		}
	}()
}

func (s *appState) handleProxyMenuCache(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
		return
	}
	profile, _ := s.current()
	s.proxyMenuMu.RLock()
	response := append([]byte(nil), s.proxyMenuResponse...)
	profileID := s.proxyMenuProfileID
	generation := s.proxyMenuGeneration
	s.proxyMenuMu.RUnlock()

	if len(response) == 0 || (profile.ID != "" && profileID != profile.ID) {
		go s.refreshProxyMenuCache()
		jsonReply(w, http.StatusOK, map[string]any{
			"ok": true, "generation": generation, "proxies": map[string]any{},
		})
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(response)
}

func (s *appState) invalidateStatusCache() {
	s.statusMu.Lock()
	s.statusData = nil
	s.statusProfileID = ""
	s.statusUpdatedAt = time.Time{}
	s.statusErr = ""
	s.statusReachable = false
	s.statusMu.Unlock()
	s.clearStatusFile()
}

func (s *appState) statusFilePath() string {
	return filepath.Join(filepath.Dir(s.path), "Runtime", "status.json")
}

func (s *appState) writeStatusFile(data []byte) {
	path := s.statusFilePath()
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return
	}

	// The menu-bar process reads this file directly to avoid spawning curl on
	// every tick. Add a local freshness marker without altering /local/status.
	snapshot := data
	var payload map[string]any
	if json.Unmarshal(data, &payload) == nil {
		payload["_menu_updated_unix_ms"] = time.Now().UnixMilli()
		if encoded, err := json.Marshal(payload); err == nil {
			snapshot = encoded
		}
	}

	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, snapshot, 0600); err == nil {
		_ = os.Rename(tmp, path)
	}
}

func (s *appState) clearStatusFile() {
	_ = os.Remove(s.statusFilePath())
}

func (s *appState) refreshStatusCache() {
	s.statusFetchMu.Lock()
	defer s.statusFetchMu.Unlock()

	p, err := s.current()
	if err != nil {
		s.statusMu.Lock()
		s.statusProfileID = ""
		s.statusUpdatedAt = time.Now()
		s.statusErr = err.Error()
		s.statusReachable = false
		s.statusMu.Unlock()
		s.clearStatusFile()
		return
	}

	data, _, remoteErr := s.remote(http.MethodGet, "/api/status", nil, nil, false)
	s.statusMu.Lock()
	defer s.statusMu.Unlock()
	s.statusProfileID = p.ID
	s.statusUpdatedAt = time.Now()
	if remoteErr != nil {
		s.statusData = nil
		s.statusErr = remoteErr.Error()
		s.statusReachable = false
		s.clearStatusFile()
		return
	}
	s.statusData = append(s.statusData[:0], data...)
	s.statusErr = ""
	s.statusReachable = true
	s.writeStatusFile(data)
}

func (s *appState) handleStatus(w http.ResponseWriter, r *http.Request) {
	p, err := s.current()
	if err != nil {
		errReply(w, err)
		return
	}

	s.statusMu.RLock()
	profileID := s.statusProfileID
	updatedAt := s.statusUpdatedAt
	reachable := s.statusReachable
	errText := s.statusErr
	data := append([]byte(nil), s.statusData...)
	s.statusMu.RUnlock()

	if profileID != p.ID || updatedAt.IsZero() || time.Since(updatedAt) > 3*time.Second {
		s.refreshStatusCache()
		s.statusMu.RLock()
		profileID = s.statusProfileID
		reachable = s.statusReachable
		errText = s.statusErr
		data = append(data[:0], s.statusData...)
		s.statusMu.RUnlock()
	}

	if profileID != p.ID || !reachable || len(data) == 0 {
		if errText == "" {
			errText = "状态暂不可用"
		}
		errReply(w, errors.New(errText))
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func (s *appState) startStatusPoller() {
	go func() {
		s.refreshStatusCache()
		ticker := time.NewTicker(1200 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				s.refreshStatusCache()
			case <-s.done:
				return
			}
		}
	}()
}

func normalizeBase(raw string, allowHTTP bool) (*url.URL, error) {
	raw = strings.TrimSpace(raw)
	if !strings.Contains(raw, "://") {
		raw = "https://" + raw
	}
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return nil, fmt.Errorf("无效 URL：%s", raw)
	}
	if u.Scheme != "https" && u.Scheme != "http" {
		return nil, errors.New("仅支持 http/https")
	}
	if u.Scheme == "http" && !allowHTTP {
		return nil, errors.New("该服务器未允许不安全 HTTP")
	}
	return u, nil
}

func joinURL(baseRaw, path string, allowHTTP bool, query url.Values) (string, error) {
	u, err := normalizeBase(baseRaw, allowHTTP)
	if err != nil {
		return "", err
	}
	basePath := strings.Trim(u.Path, "/")
	reqPath := strings.Trim(path, "/")
	if basePath == "" {
		u.Path = "/" + reqPath
	} else if reqPath == "" {
		u.Path = "/" + basePath
	} else {
		u.Path = "/" + basePath + "/" + reqPath
	}
	if query != nil {
		u.RawQuery = query.Encode()
	}
	return u.String(), nil
}

func (s *appState) remote(method, path string, body []byte, query url.Values, direct bool) ([]byte, int, error) {
	p, err := s.current()
	if err != nil {
		return nil, 0, err
	}
	coreSecret := s.secretFor(p.ID)
	secret := coreSecret
	base := p.ManagementURL
	if direct {
		base = p.CoreControllerURL
		if strings.TrimSpace(base) == "" {
			return nil, 0, errors.New("未配置 Direct Core Controller URL")
		}
		if controllerSecret := s.controllerSecretFor(p.ID); controllerSecret != "" {
			secret = controllerSecret
		}
	} else if secret == "" {
		return nil, 0, errors.New("当前服务器尚未配置 Core Secret")
	}
	target, err := joinURL(base, path, p.AllowInsecureHTTP, query)
	if err != nil {
		return nil, 0, err
	}
	data, code, requestErr := s.remoteRequest(method, target, body, secret)
	if direct && code == http.StatusUnauthorized {
		return data, code, errors.New("Mihomo Controller HTTP 401：认证失败。请在设置的 Controller Secret 中填写 config.yaml 的 secret；它可以与管理面板的 Core Secret 不同")
	}
	return data, code, requestErr
}

func (s *appState) remoteRequest(method, target string, body []byte, secret string) ([]byte, int, error) {
	maxAttempts := 1
	if method == http.MethodGet || method == http.MethodHead {
		maxAttempts = 3
	}

	var lastData []byte
	var lastCode int
	var lastErr error

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		req, err := http.NewRequest(method, target, strings.NewReader(string(body)))
		if err != nil {
			return nil, 0, err
		}
		if secret != "" {
			req.Header.Set("Authorization", "Bearer "+secret)
		}
		req.Header.Set("Accept", "application/json")
		if len(body) > 0 {
			req.Header.Set("Content-Type", "application/json")
		}

		resp, err := s.client.Do(req)
		if err != nil {
			lastErr = err
			lastCode = 0
			if attempt < maxAttempts {
				time.Sleep(time.Duration(attempt) * 250 * time.Millisecond)
				continue
			}
			return nil, 0, err
		}

		data, readErr := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
		_ = resp.Body.Close()
		lastData = data
		lastCode = resp.StatusCode

		if readErr != nil {
			lastErr = readErr
			if attempt < maxAttempts {
				time.Sleep(time.Duration(attempt) * 250 * time.Millisecond)
				continue
			}
			return data, resp.StatusCode, readErr
		}

		if resp.StatusCode >= 200 && resp.StatusCode < 300 {
			return data, resp.StatusCode, nil
		}

		msg := remoteMessage(data, nil)
		rawLower := strings.ToLower(string(data))
		if resp.StatusCode == 530 &&
			(strings.Contains(rawLower, "1033") || strings.Contains(rawLower, "cloudflare")) {
			msg = "Cloudflare Tunnel 暂时断开（Error 1033）。Controller 主机当前不可达，请稍后重试。"
		}
		if msg == "未知错误" {
			msg = strings.TrimSpace(string(data))
			if msg == "" {
				msg = resp.Status
			}
		}
		lastErr = fmt.Errorf("远端 HTTP %d：%s", resp.StatusCode, msg)

		if attempt < maxAttempts && isTransientGatewayStatus(resp.StatusCode) {
			time.Sleep(time.Duration(attempt) * 250 * time.Millisecond)
			continue
		}
		return data, resp.StatusCode, lastErr
	}

	return lastData, lastCode, lastErr
}

func joinProxyURL(baseRaw, group string, allowHTTP bool) (string, error) {
	u, err := normalizeBase(baseRaw, allowHTTP)
	if err != nil {
		return "", err
	}
	group = strings.TrimSpace(group)
	if group == "" {
		return "", errors.New("代理组不能为空")
	}

	baseDecoded := strings.Trim(u.Path, "/")
	baseEscaped := strings.Trim(u.EscapedPath(), "/")
	decodedParts := []string{}
	escapedParts := []string{}
	if baseDecoded != "" {
		decodedParts = append(decodedParts, baseDecoded)
		escapedParts = append(escapedParts, baseEscaped)
	}
	decodedParts = append(decodedParts, "proxies", group)
	escapedParts = append(escapedParts, "proxies", url.PathEscape(group))
	u.Path = "/" + strings.Join(decodedParts, "/")
	u.RawPath = "/" + strings.Join(escapedParts, "/")
	u.RawQuery = ""
	u.Fragment = ""
	return u.String(), nil
}

func joinGroupDelayURL(baseRaw, group string, allowHTTP bool, query url.Values) (string, error) {
	u, err := normalizeBase(baseRaw, allowHTTP)
	if err != nil {
		return "", err
	}
	group = strings.TrimSpace(group)
	if group == "" {
		return "", errors.New("代理组不能为空")
	}

	baseDecoded := strings.Trim(u.Path, "/")
	baseEscaped := strings.Trim(u.EscapedPath(), "/")
	decodedParts := []string{}
	escapedParts := []string{}
	if baseDecoded != "" {
		decodedParts = append(decodedParts, baseDecoded)
		escapedParts = append(escapedParts, baseEscaped)
	}
	decodedParts = append(decodedParts, "group", group, "delay")
	escapedParts = append(escapedParts, "group", url.PathEscape(group), "delay")
	u.Path = "/" + strings.Join(decodedParts, "/")
	u.RawPath = "/" + strings.Join(escapedParts, "/")
	if query != nil {
		u.RawQuery = query.Encode()
	} else {
		u.RawQuery = ""
	}
	u.Fragment = ""
	return u.String(), nil
}

func jsonReply(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
func errReply(w http.ResponseWriter, err error) {
	jsonReply(w, http.StatusBadGateway, map[string]any{"ok": false, "message": err.Error()})
}

func (s *appState) auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Mihomo-Local-Token") != s.token {
			jsonReply(w, 403, map[string]any{"ok": false, "message": "local token rejected"})
			return
		}
		next(w, r)
	}
}

func (s *appState) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	b, _ := assets.ReadFile("ui/index.html")
	page := strings.ReplaceAll(string(b), "__LOCAL_TOKEN__", s.token)
	page = strings.ReplaceAll(page, "__APP_VERSION__", appVersion)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = io.WriteString(w, page)
}

func (s *appState) handleProfiles(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	type view struct {
		Profile
		HasSecret           bool `json:"hasSecret"`
		HasControllerSecret bool `json:"hasControllerSecret"`
	}
	out := make([]view, 0, len(s.settings.Profiles))
	for _, p := range s.settings.Profiles {
		out = append(out, view{p, s.secretFor(p.ID) != "", s.controllerSecretFor(p.ID) != ""})
	}
	jsonReply(w, 200, map[string]any{"ok": true, "selectedID": s.settings.SelectedID, "profiles": out, "version": appVersion, "build": buildNumber})
}

func (s *appState) handleProfileSave(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Profile          Profile `json:"profile"`
		Secret           string  `json:"secret"`
		ControllerSecret string  `json:"controllerSecret"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&in); err != nil {
		errReply(w, err)
		return
	}
	p := in.Profile
	if p.ID == "" {
		p.ID = newID()
	}
	if strings.TrimSpace(p.Name) == "" {
		p.Name = "服务器"
	}
	if p.ConfigPath == "" {
		p.ConfigPath = "/etc/mihomo/config.yaml"
	}
	if _, err := normalizeBase(p.ManagementURL, p.AllowInsecureHTTP); err != nil {
		errReply(w, err)
		return
	}
	s.mu.Lock()
	found := false
	for i := range s.settings.Profiles {
		if s.settings.Profiles[i].ID == p.ID {
			s.settings.Profiles[i] = p
			found = true
			break
		}
	}
	if !found {
		s.settings.Profiles = append(s.settings.Profiles, p)
	}
	s.settings.SelectedID = p.ID
	err := s.saveLocked()
	s.mu.Unlock()
	if err != nil {
		errReply(w, err)
		return
	}
	if in.Secret != "" {
		if err := keychainSet(p.ID, in.Secret); err != nil {
			errReply(w, fmt.Errorf("Keychain 保存失败：%w", err))
			return
		}
		s.cacheSecret(p.ID, in.Secret)
	}
	if in.ControllerSecret != "" {
		if err := controllerKeychainSet(p.ID, in.ControllerSecret); err != nil {
			errReply(w, fmt.Errorf("Controller Secret Keychain 保存失败：%w", err))
			return
		}
		s.cacheControllerSecret(p.ID, in.ControllerSecret)
	}
	s.invalidateStatusCache()
	jsonReply(w, 200, map[string]any{"ok": true, "message": "设置已保存", "id": p.ID})
}

func (s *appState) handleControllerSecretClear(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
		return
	}
	p, err := s.current()
	if err != nil {
		errReply(w, err)
		return
	}
	controllerKeychainDelete(p.ID)
	s.cacheControllerSecret(p.ID, "")
	jsonReply(w, http.StatusOK, map[string]any{"ok": true, "message": "Controller Secret 已清除，将回退使用 Core Secret"})
}

func (s *appState) handleProfileSelect(w http.ResponseWriter, r *http.Request) {
	var in struct {
		ID string `json:"id"`
	}
	_ = json.NewDecoder(r.Body).Decode(&in)
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, p := range s.settings.Profiles {
		if p.ID == in.ID {
			s.settings.SelectedID = in.ID
			if err := s.saveLocked(); err != nil {
				errReply(w, err)
				return
			}
			s.invalidateStatusCache()
			s.invalidateProxyMenuCache()
			go s.refreshProxyMenuCache()
			jsonReply(w, 200, map[string]any{"ok": true})
			return
		}
	}
	errReply(w, errors.New("服务器不存在"))
}
func (s *appState) handleProfileDelete(w http.ResponseWriter, r *http.Request) {
	var in struct {
		ID string `json:"id"`
	}
	_ = json.NewDecoder(r.Body).Decode(&in)
	s.mu.Lock()
	idx := -1
	for i, p := range s.settings.Profiles {
		if p.ID == in.ID {
			idx = i
			break
		}
	}
	if idx < 0 {
		s.mu.Unlock()
		errReply(w, errors.New("服务器不存在"))
		return
	}
	s.settings.Profiles = append(s.settings.Profiles[:idx], s.settings.Profiles[idx+1:]...)
	if len(s.settings.Profiles) == 0 {
		p := defaultProfile()
		s.settings.Profiles = []Profile{p}
		s.settings.SelectedID = p.ID
	} else if s.settings.SelectedID == in.ID {
		s.settings.SelectedID = s.settings.Profiles[0].ID
	}
	err := s.saveLocked()
	s.mu.Unlock()
	keychainDelete(in.ID)
	controllerKeychainDelete(in.ID)
	s.forgetSecret(in.ID)
	s.forgetControllerSecret(in.ID)
	s.invalidateStatusCache()
	s.invalidateProxyMenuCache()
	go s.refreshProxyMenuCache()
	if err != nil {
		errReply(w, err)
		return
	}
	jsonReply(w, 200, map[string]any{"ok": true})
}

func (s *appState) proxy(path string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var body []byte
		if r.Body != nil {
			body, _ = io.ReadAll(io.LimitReader(r.Body, 2<<20))
		}
		data, code, err := s.remote(r.Method, path, body, r.URL.Query(), false)
		if err != nil {
			errReply(w, err)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.WriteHeader(code)
		_, _ = w.Write(data)
	}
}

func isTransientGatewayStatus(code int) bool {
	switch code {
	case http.StatusBadGateway, http.StatusServiceUnavailable, http.StatusGatewayTimeout,
		520, 521, 522, 523, 524, 525, 526, 530:
		return true
	default:
		return false
	}
}

func remoteMessage(data []byte, fallback error) string {
	var payload struct {
		Message   string `json:"message"`
		Title     string `json:"title"`
		Detail    string `json:"detail"`
		ErrorCode int    `json:"error_code"`
		ErrorName string `json:"error_name"`
		Retryable any    `json:"retryable"`
	}
	if len(data) > 0 && json.Unmarshal(data, &payload) == nil {
		message := strings.TrimSpace(payload.Message)
		title := strings.TrimSpace(payload.Title)
		detail := strings.TrimSpace(payload.Detail)

		if payload.ErrorCode == 1033 ||
			strings.Contains(strings.ToLower(title), "error 1033") ||
			strings.Contains(strings.ToLower(detail), "cloudflare tunnel") {
			return "Cloudflare Tunnel 暂时断开（Error 1033）。Controller 主机当前不可达，请稍后重试。"
		}
		if message != "" {
			return message
		}
		if title != "" && detail != "" {
			return title + "：" + detail
		}
		if detail != "" {
			return detail
		}
		if title != "" {
			return title
		}
	}
	if fallback != nil {
		return strings.TrimSpace(fallback.Error())
	}
	return "未知错误"
}

func subscriptionReloadTimedOut(data []byte, err error) bool {
	message := remoteMessage(data, err)
	lower := strings.ToLower(message)
	reloadFailed := strings.Contains(message, "热重载失败") || strings.Contains(message, "Mihomo 热重载失败")
	timedOut := strings.Contains(lower, "timed out") || strings.Contains(lower, "timeout") || strings.Contains(message, "超时")
	rolledBack := strings.Contains(message, "已恢复") || strings.Contains(message, "回滚")
	return reloadFailed && timedOut && rolledBack
}

func (s *appState) coreLifecycleAction(action string) ([]byte, int, error) {
	body, _ := json.Marshal(map[string]string{"action": action})
	return s.remote(http.MethodPost, "/api/action", body, nil, false)
}

func (s *appState) handleProxyMode(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		data, code, err := s.remote(http.MethodGet, "/configs", nil, nil, true)
		if err != nil {
			errReply(w, err)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.WriteHeader(code)
		_, _ = w.Write(data)
	case http.MethodPost:
		var in struct {
			Mode string `json:"mode"`
		}
		if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&in); err != nil {
			jsonReply(w, http.StatusBadRequest, map[string]any{"ok": false, "message": "无效请求"})
			return
		}
		mode := strings.ToLower(strings.TrimSpace(in.Mode))
		if mode != "rule" && mode != "global" && mode != "direct" {
			jsonReply(w, http.StatusBadRequest, map[string]any{"ok": false, "message": "运行模式仅支持 rule/global/direct"})
			return
		}
		body, _ := json.Marshal(map[string]string{"mode": mode})
		if _, _, err := s.remote(http.MethodPatch, "/configs", body, nil, true); err != nil {
			errReply(w, err)
			return
		}
		jsonReply(w, http.StatusOK, map[string]any{"ok": true, "mode": mode})
	default:
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
	}
}

func (s *appState) handleProxyGroups(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
		return
	}
	data, code, err := s.remote(http.MethodGet, "/group", nil, nil, true)
	if err != nil {
		errReply(w, err)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_, _ = w.Write(data)
}

func (s *appState) handleProxies(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
		return
	}
	data, code, err := s.fetchMergedProxyPayload()
	if err != nil {
		errReply(w, err)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_, _ = w.Write(data)
}

type proxyDelayRequest struct {
	Group    string `json:"group"`
	URL      string `json:"url"`
	Expected string `json:"expected"`
	Timeout  int    `json:"timeout"`
}

func (s *appState) runProxyDelay(in proxyDelayRequest) (map[string]int, error) {
	in.Group = strings.TrimSpace(in.Group)
	if in.Group == "" {
		return nil, errors.New("代理组不能为空")
	}
	profile, err := s.current()
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(profile.CoreControllerURL) == "" {
		return nil, errors.New("未配置 Direct Core Controller URL")
	}

	testURL := strings.TrimSpace(in.URL)
	if testURL == "" {
		testURL = "https://www.gstatic.com/generate_204"
	}
	timeout := in.Timeout
	if timeout <= 0 {
		timeout = 5000
	}
	if timeout < 1000 {
		timeout = 1000
	}
	if timeout > 30000 {
		timeout = 30000
	}
	query := url.Values{
		"url":     []string{testURL},
		"timeout": []string{fmt.Sprintf("%d", timeout)},
	}
	if expected := strings.TrimSpace(in.Expected); expected != "" {
		query.Set("expected", expected)
	}

	target, err := joinGroupDelayURL(profile.CoreControllerURL, in.Group, profile.AllowInsecureHTTP, query)
	if err != nil {
		return nil, err
	}
	data, code, err := s.remoteRequest(http.MethodGet, target, nil, s.controllerSecret(profile))
	if err != nil {
		if code == http.StatusUnauthorized {
			return nil, errors.New("Mihomo Controller HTTP 401：认证失败。请检查 Controller Secret")
		}
		return nil, err
	}

	// Decode flexibly so compatible cores returning JSON numbers through a
	// generic encoder cannot produce a false "success but no latency" state.
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, errors.New("Controller 返回了无法识别的测速结果")
	}
	delays := make(map[string]int, len(raw))
	for name, value := range raw {
		if delay, ok := intFromJSONValue(value); ok {
			delays[name] = delay
		}
	}
	if len(raw) > 0 && len(delays) == 0 {
		return nil, errors.New("Controller 测速返回值没有可解析的延时数据")
	}

	normalized := make(map[string]int, len(delays)*2)
	for name, delay := range delays {
		normalized[name] = delay
		if resolved := s.resolveProxyNameFromCachedMenu(name); resolved != "" && resolved != name {
			normalized[resolved] = delay
		}
	}
	s.cacheProxyDelays(profile.ID, normalized)
	go s.refreshProxyMenuCache()
	return delays, nil
}

func (s *appState) handleProxyDelay(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
		return
	}
	var in proxyDelayRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&in); err != nil {
		jsonReply(w, http.StatusBadRequest, map[string]any{"ok": false, "message": "无效请求"})
		return
	}
	delays, err := s.runProxyDelay(in)
	if err != nil {
		errReply(w, err)
		return
	}
	jsonReply(w, http.StatusOK, map[string]any{
		"ok": true, "group": strings.TrimSpace(in.Group), "count": len(delays), "delays": delays,
	})
}

func (s *appState) handleProxyDelayAsync(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
		return
	}
	var in proxyDelayRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&in); err != nil {
		jsonReply(w, http.StatusBadRequest, map[string]any{"ok": false, "message": "无效请求"})
		return
	}
	in.Group = strings.TrimSpace(in.Group)
	if in.Group == "" {
		jsonReply(w, http.StatusBadRequest, map[string]any{"ok": false, "message": "代理组不能为空"})
		return
	}
	go func() {
		if _, err := s.runProxyDelay(in); err != nil {
			log.Printf("status menu proxy delay %q: %v", in.Group, err)
		}
	}()
	jsonReply(w, http.StatusAccepted, map[string]any{
		"ok": true, "message": "已开始测速", "group": in.Group,
	})
}

type proxySelectRequest struct {
	Group string `json:"group"`
	Name  string `json:"name"`
}

func (s *appState) runProxySelect(in proxySelectRequest) error {
	in.Group = strings.TrimSpace(in.Group)
	in.Name = strings.TrimSpace(in.Name)
	if in.Group == "" || in.Name == "" {
		return errors.New("代理组和代理名称不能为空")
	}
	profile, err := s.current()
	if err != nil {
		return err
	}
	if strings.TrimSpace(profile.CoreControllerURL) == "" {
		return errors.New("未配置 Direct Core Controller URL")
	}
	target, err := joinProxyURL(profile.CoreControllerURL, in.Group, profile.AllowInsecureHTTP)
	if err != nil {
		return err
	}
	body, _ := json.Marshal(map[string]string{"name": in.Name})
	if _, code, err := s.remoteRequest(http.MethodPut, target, body, s.controllerSecret(profile)); err != nil {
		if code == http.StatusUnauthorized {
			return errors.New("Mihomo Controller HTTP 401：认证失败。请在设置的 Controller Secret 中填写 config.yaml 的 secret；它可以与管理面板的 Core Secret 不同")
		}
		return err
	}
	go s.refreshProxyMenuCache()
	return nil
}

func (s *appState) handleProxySelect(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
		return
	}
	var in proxySelectRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&in); err != nil {
		jsonReply(w, http.StatusBadRequest, map[string]any{"ok": false, "message": "无效请求"})
		return
	}
	if err := s.runProxySelect(in); err != nil {
		errReply(w, err)
		return
	}
	jsonReply(w, http.StatusOK, map[string]any{"ok": true, "group": strings.TrimSpace(in.Group), "name": strings.TrimSpace(in.Name)})
}

func (s *appState) handleProxySelectAsync(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonReply(w, http.StatusMethodNotAllowed, map[string]any{"ok": false, "message": "method not allowed"})
		return
	}
	var in proxySelectRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&in); err != nil {
		jsonReply(w, http.StatusBadRequest, map[string]any{"ok": false, "message": "无效请求"})
		return
	}
	in.Group = strings.TrimSpace(in.Group)
	in.Name = strings.TrimSpace(in.Name)
	if in.Group == "" || in.Name == "" {
		jsonReply(w, http.StatusBadRequest, map[string]any{"ok": false, "message": "代理组和代理名称不能为空"})
		return
	}
	go func() {
		if err := s.runProxySelect(in); err != nil {
			log.Printf("status menu proxy select %q -> %q: %v", in.Group, in.Name, err)
		}
	}()
	jsonReply(w, http.StatusAccepted, map[string]any{
		"ok": true, "message": "已提交线路切换", "group": in.Group, "name": in.Name,
	})
}

func (s *appState) handleSubscriptions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.proxy("/api/subscriptions")(w, r)
		return
	}

	body, _ := io.ReadAll(io.LimitReader(r.Body, 2<<20))
	data, code, err := s.remote(http.MethodPost, "/api/subscriptions", body, nil, false)
	if err == nil {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.WriteHeader(code)
		_, _ = w.Write(data)
		return
	}
	if !subscriptionReloadTimedOut(data, err) {
		errReply(w, errors.New(remoteMessage(data, err)))
		return
	}

	// v4.0.0 compatibility fallback: its subscription endpoint wraps save,
	// renderer validation and hot reload into one transaction. If /configs times
	// out, v4.0.0 rolls the files back. Stop the Core, re-run the same transaction
	// (which now saves without hot reload), then start the Core with the new config.
	if stopData, _, stopErr := s.coreLifecycleAction("stop"); stopErr != nil {
		errReply(w, fmt.Errorf("订阅保存时远端热重载超时；自动安全重启也无法停止 Core：%s", remoteMessage(stopData, stopErr)))
		return
	}
	time.Sleep(300 * time.Millisecond)

	saveData, _, saveErr := s.remote(http.MethodPost, "/api/subscriptions", body, nil, false)
	if saveErr != nil {
		_, _, _ = s.coreLifecycleAction("start")
		errReply(w, fmt.Errorf("订阅保存时远端热重载超时；停止 Core 后再次保存仍失败：%s", remoteMessage(saveData, saveErr)))
		return
	}

	if startData, _, startErr := s.coreLifecycleAction("start"); startErr != nil {
		errReply(w, fmt.Errorf("订阅配置已经保存，但 Core 重新启动失败：%s。请到 Core 控制页手动启动", remoteMessage(startData, startErr)))
		return
	}

	s.invalidateStatusCache()
	go s.refreshStatusCache()
	jsonReply(w, http.StatusOK, map[string]any{
		"ok":        true,
		"message":   "订阅已保存并应用；远端热重载超时，已自动通过安全重启 Core 应用新配置。",
		"applyMode": "restart-fallback",
	})
}

func (s *appState) handleAction(w http.ResponseWriter, r *http.Request) {
	var in map[string]any
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		errReply(w, err)
		return
	}
	a, _ := in["action"].(string)
	allowed := map[string]bool{"start": true, "stop": true, "restart": true, "reload": true, "apply_subscriptions": true}
	if !allowed[a] {
		errReply(w, errors.New("不支持的 Core action"))
		return
	}
	body, _ := json.Marshal(map[string]string{"action": a})
	data, code, err := s.remote("POST", "/api/action", body, nil, false)
	if err != nil {
		errReply(w, err)
		return
	}
	s.invalidateStatusCache()
	go s.refreshStatusCache()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_, _ = w.Write(data)
}

func (s *appState) handleReload(w http.ResponseWriter, r *http.Request) {
	p, err := s.current()
	if err != nil {
		errReply(w, err)
		return
	}
	if strings.TrimSpace(p.CoreControllerURL) == "" {
		r.Body = io.NopCloser(strings.NewReader(`{"action":"reload"}`))
		s.handleAction(w, r)
		return
	}
	body, _ := json.Marshal(map[string]string{"path": p.ConfigPath, "payload": ""})
	data, code, err := s.remote("PUT", "/configs", body, url.Values{"force": []string{"true"}}, true)
	if err != nil {
		errReply(w, err)
		return
	}
	if len(data) == 0 {
		data = []byte(`{"ok":true,"message":"配置已通过 Direct Controller 重载"}`)
	}
	s.invalidateStatusCache()
	go s.refreshStatusCache()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_, _ = w.Write(data)
}

func (s *appState) handleUpdateApply(w http.ResponseWriter, r *http.Request) {
	p, err := s.current()
	if err != nil {
		errReply(w, err)
		return
	}
	body, _ := json.Marshal(map[string]bool{"preserve_settings": p.PreserveSettingsOnUpdate})
	data, code, err := s.remote("POST", "/api/project-update/apply", body, nil, false)
	if err != nil {
		errReply(w, err)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_, _ = w.Write(data)
}
func (s *appState) handleMeta(w http.ResponseWriter, r *http.Request) {
	p, err := s.current()
	if err != nil {
		errReply(w, err)
		return
	}
	jsonReply(w, 200, map[string]any{"ok": true, "url": p.MetaCubeXDURL})
}

func (s *appState) handleMenuPreferences(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.settings.MenuPreferences == nil {
		s.settings.MenuPreferences = &MenuPreferences{ShowIcon: true, ShowStatus: true, ShowSpeed: true}
	}
	if r.Method == http.MethodPost {
		var in MenuPreferences
		if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&in); err != nil {
			errReply(w, err)
			return
		}
		// Never persist an entirely invisible menu-bar item. If the user turns
		// off all three elements, fall back to the icon so the menu remains reachable.
		if !in.ShowIcon && !in.ShowStatus && !in.ShowSpeed {
			in.ShowIcon = true
		}
		s.settings.MenuPreferences = &in
		if err := s.saveLocked(); err != nil {
			errReply(w, err)
			return
		}
	}
	prefs := *s.settings.MenuPreferences
	jsonReply(w, 200, map[string]any{
		"ok":         true,
		"showIcon":   prefs.ShowIcon,
		"showStatus": prefs.ShowStatus,
		"showSpeed":  prefs.ShowSpeed,
	})
}

func (s *appState) handleOpenURL(w http.ResponseWriter, r *http.Request) {
	if runtime.GOOS != "darwin" {
		errReply(w, errors.New("打开外部链接仅支持 macOS"))
		return
	}
	var in struct {
		URL string `json:"url"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&in); err != nil {
		errReply(w, err)
		return
	}
	u, err := url.Parse(strings.TrimSpace(in.URL))
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		errReply(w, errors.New("无效外部 URL"))
		return
	}
	if err := exec.Command("/usr/bin/open", u.String()).Start(); err != nil {
		errReply(w, err)
		return
	}
	jsonReply(w, 200, map[string]any{"ok": true})
}

func (s *appState) handleClipboard(w http.ResponseWriter, r *http.Request) {
	if runtime.GOOS != "darwin" {
		errReply(w, errors.New("剪贴板粘贴仅支持 macOS"))
		return
	}
	out, err := exec.Command("/usr/bin/pbpaste").Output()
	if err != nil {
		errReply(w, fmt.Errorf("读取剪贴板失败：%w", err))
		return
	}
	if len(out) > 64<<10 {
		out = out[:64<<10]
	}
	jsonReply(w, 200, map[string]any{"ok": true, "text": string(out)})
}

func (s *appState) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", s.handleIndex)
	mux.HandleFunc("/local/profiles", s.auth(s.handleProfiles))
	mux.HandleFunc("/local/profile/save", s.auth(s.handleProfileSave))
	mux.HandleFunc("/local/profile/select", s.auth(s.handleProfileSelect))
	mux.HandleFunc("/local/profile/delete", s.auth(s.handleProfileDelete))
	mux.HandleFunc("/local/status", s.auth(s.handleStatus))
	mux.HandleFunc("/local/action", s.auth(s.handleAction))
	mux.HandleFunc("/local/reload-config", s.auth(s.handleReload))
	mux.HandleFunc("/local/proxy-mode", s.auth(s.handleProxyMode))
	mux.HandleFunc("/local/proxy-groups", s.auth(s.handleProxyGroups))
	mux.HandleFunc("/local/proxies", s.auth(s.handleProxies))
	mux.HandleFunc("/local/proxy-menu-cache", s.auth(s.handleProxyMenuCache))
	mux.HandleFunc("/local/proxy-delay", s.auth(s.handleProxyDelay))
	mux.HandleFunc("/local/proxy-delay-async", s.auth(s.handleProxyDelayAsync))
	mux.HandleFunc("/local/proxy-select", s.auth(s.handleProxySelect))
	mux.HandleFunc("/local/proxy-select-async", s.auth(s.handleProxySelectAsync))
	mux.HandleFunc("/local/controller-secret/clear", s.auth(s.handleControllerSecretClear))
	mux.HandleFunc("/local/subscriptions", s.auth(s.handleSubscriptions))
	mux.HandleFunc("/local/logs", s.auth(s.proxy("/api/logs")))
	mux.HandleFunc("/local/update/check", s.auth(s.proxy("/api/project-update/check")))
	mux.HandleFunc("/local/update/apply", s.auth(s.handleUpdateApply))
	mux.HandleFunc("/local/update/log", s.auth(s.proxy("/api/project-update/log")))
	mux.HandleFunc("/local/metacubexd", s.auth(s.handleMeta))
	mux.HandleFunc("/local/menu-preferences", s.auth(s.handleMenuPreferences))
	mux.HandleFunc("/local/open-url", s.auth(s.handleOpenURL))
	mux.HandleFunc("/local/clipboard", s.auth(s.handleClipboard))
	mux.HandleFunc("/local/quit", s.auth(func(w http.ResponseWriter, r *http.Request) {
		jsonReply(w, 200, map[string]any{"ok": true})
		s.doneOnce.Do(func() { close(s.done) })
		go func() { time.Sleep(200 * time.Millisecond); _ = s.server.Close() }()
	}))
	return mux
}

func shellQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'" }

func menuScript(base, token, statusFile string) string {
	// JXA status item. All commands talk only to the token-protected loopback API.
	return fmt.Sprintf(`ObjC.import('Cocoa'); ObjC.import('WebKit');
var std = Application.currentApplication(); std.includeStandardAdditions = true;
var BASE = %q, TOKEN = %q, STATUS_FILE = %q; var PROXY_FILE = String(STATUS_FILE).replace(/status\.json$/, 'proxies.json');
function sh(s){ return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
function request(path, method, obj, quiet){
  try {
    var cmd='/usr/bin/curl -fsS --max-time 4 -H '+sh('X-Mihomo-Local-Token: '+TOKEN);
    if(method==='POST') cmd+=' -X POST -H '+sh('Content-Type: application/json')+' --data '+sh(JSON.stringify(obj||{}));
    cmd+=' '+sh(BASE+path);
    return JSON.parse(std.doShellScript(cmd));
  } catch(e) {
    if(!quiet) std.displayNotification(String(e), {withTitle:'Mihomo Core Manager'});
    return null;
  }
}
function get(path, quiet){ return request(path,'GET',null,quiet); }
function post(path, obj, quiet){ return request(path,'POST',obj,quiet); }
function fmtRate(raw){
  var value=Math.max(0,Number(raw||0)), units=['B/s','KB/s','MB/s','GB/s','TB/s'], i=0;
  while(value>=1024 && i<units.length-1){ value/=1024; i++; }
  var digits=value>=100?0:(value>=10?1:2);
  return value.toFixed(digits)+' '+units[i];
}
function fmtMenuRate(raw){
  var value=Math.max(0,Number(raw||0)), units=['B/s','KB/s','MB/s','GB/s','TB/s'], i=0;
  while(value>=1024 && i<units.length-1){ value/=1024; i++; }
  var digits=i===0?0:(value<10?1:0);
  return value.toFixed(digits)+' '+units[i];
}
function statusRateParts(raw){
  var value=Math.max(0,Number(raw||0)), units=['B/s','KB/s','MB/s','GB/s','TB/s'], i=0;
  while(value>=1024 && i<units.length-1){ value/=1024; i++; }
  // The value label has exactly four monospaced character cells. Keep the
  // actual text within those cells and let the adjacent unit label change
  // independently as traffic crosses B/s, KB/s, MB/s and larger thresholds.
  var number=(i>0 && value<10)?value.toFixed(1):value.toFixed(0);
  return {value:number,unit:units[i]};
}
function statusFromFile(){
  try {
    var err=Ref(), text=$.NSString.stringWithContentsOfFileEncodingError($(STATUS_FILE),4,err);
    if(!text) return null;
    return JSON.parse(ObjC.unwrap(text));
  } catch(e) { return null; }
}

function proxyMenuFromFile(){
  try {
    var err=Ref(), text=$.NSString.stringWithContentsOfFileEncodingError($(PROXY_FILE),4,err);
    if(!text) return null;
    return JSON.parse(ObjC.unwrap(text));
  } catch(e) { return null; }
}

// WKWebView consumes mouse events inside a full-size content view, so
// movableByWindowBackground alone is not enough. A transparent native drag strip
// sits over the Dashboard title bar and forwards mouse-down to NSWindow's native
// performWindowDragWithEvent:, restoring normal macOS title-bar movement.
ObjC.registerSubclass({name:'MihomoWindowDragView', superclass:'NSView', methods:{
'mouseDown:':{types:['void',['id']],implementation:function(event){try{this.window.performWindowDragWithEvent(event);}catch(e){}}}
}});
ObjC.registerSubclass({name:'MihomoStatusOverlayView', superclass:'NSView', methods:{
'mouseDown:':{types:['void',['id']],implementation:function(event){try{statusItem.button.performClick(null);}catch(e){}}}
}});
ObjC.registerSubclass({name:'MihomoStatusLabel', superclass:'NSTextField', methods:{
'mouseDown:':{types:['void',['id']],implementation:function(event){try{statusItem.button.performClick(null);}catch(e){}}}
}});
ObjC.registerSubclass({name:'MihomoStatusIconView', superclass:'NSImageView', methods:{
'mouseDown:':{types:['void',['id']],implementation:function(event){try{statusItem.button.performClick(null);}catch(e){}}}
}});
var cocoaApp=$.NSApplication.sharedApplication; cocoaApp.setActivationPolicy(1);
var rect=$.NSMakeRect(0,0,1180,760);
var win=$.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(rect,32783,2,false);
win.title='Mihomo Core 管理面板'; win.titleVisibility=1; win.titlebarAppearsTransparent=true; win.movableByWindowBackground=true;
var host=$.NSView.alloc.initWithFrame(rect); host.autoresizingMask=18; win.contentView=host;
var web=$.WKWebView.alloc.initWithFrame(host.bounds); web.autoresizingMask=18; host.addSubview(web);
var dragStrip=$.MihomoWindowDragView.alloc.initWithFrame($.NSMakeRect(0,rect.size.height-36,rect.size.width,36)); dragStrip.autoresizingMask=10; host.addSubview(dragStrip);
win.center;
function showURL(u){ try{var url=$.NSURL.URLWithString($(u));var req=$.NSURLRequest.requestWithURL(url);web.loadRequest(req);win.makeKeyAndOrderFront(null);cocoaApp.activateIgnoringOtherApps(true);}catch(e){std.displayNotification(String(e),{withTitle:'Mihomo Core Manager'});} }
function openHash(h){ showURL(BASE+'/#'+h); }

var statusItem=null, statusHeader=null, speedHeader=null, prefIconItem=null, prefStatusItem=null, prefSpeedItem=null, iconOnlyItem=null, startItem=null, stopItem=null, serverMenu=null, serverRoot=null, proxyHeader=null, proxyEndSeparator=null, proxyMenuRoots=[], proxyMenuData={}, proxyMenuGeneration=-1, proxySubmenuBuilt={}, proxyMenuTick=0;
var showIcon=true, showStatus=true, showSpeed=true, lastRunning=false, lastReachable=false, lastUp=0, lastDown=0, lastCoreVersion='--';
var appSymbol=null, missingSnapshotTicks=0;
var statusOverlay=null, statusIconView=null, statusDot=null, upValueLabel=null, upUnitLabel=null, downValueLabel=null, downUnitLabel=null;
function savePrefs(){ post('/local/menu-preferences',{showIcon:showIcon,showStatus:showStatus,showSpeed:showSpeed},true); }
function syncPrefItems(){
  if(prefIconItem) prefIconItem.state=showIcon?1:0;
  if(prefStatusItem) prefStatusItem.state=showStatus?1:0;
  if(prefSpeedItem) prefSpeedItem.state=showSpeed?1:0;
  if(iconOnlyItem) iconOnlyItem.state=(showIcon&&!showStatus&&!showSpeed)?1:0;
}
function keepMenuVisible(){if(!showIcon&&!showStatus&&!showSpeed)showIcon=true;}
function safeSingleLineTitle(){
  var state=lastReachable?(lastRunning?'Running':'Stopped'):'Offline';
  var parts=[];
  if(showStatus) parts.push(state);
  if(showSpeed) parts.push(fmtMenuRate(lastUp)+'  '+fmtMenuRate(lastDown));
  return parts.join('   ');
}
function setStatusOverlayHidden(hidden){
  if(statusOverlay) statusOverlay.hidden=hidden;
}
function renderStatusSpeedOverlay(){
  var up=statusRateParts(lastUp), down=statusRateParts(lastDown);
  var iconWidth=showIcon?20:0, dotWidth=(!showIcon&&showStatus)?9:0;
  var speedX=3+iconWidth+dotWidth;
  var width=speedX+49+3;
  statusItem.length=width;
  statusOverlay.frame=$.NSMakeRect(0,0,width,22);
  statusOverlay.hidden=false;

  statusIconView.hidden=!showIcon;
  if(showIcon){
    statusIconView.frame=$.NSMakeRect(3,4,14,14);
    statusIconView.image=appSymbol;
  }

  statusDot.hidden=!showStatus;
  if(showStatus){
    statusDot.frame=showIcon?$.NSMakeRect(14,0.5,7,8):$.NSMakeRect(2,6.2,7,8);
    statusDot.textColor=lastReachable?(lastRunning?$.NSColor.systemGreenColor:$.NSColor.systemOrangeColor):$.NSColor.secondaryLabelColor;
  }

  // v1.2.0: never rely on NSStatusBarButton multiline title rendering.
  // Two independent native labels are pinned near the bottom of the 22pt menu
  // bar. Numeric labels are left aligned in four monospaced cells; units sit in
  // their own adjacent field. This keeps both rows visible on normal macOS menu
  // bars without the crash-prone NSButtonCell/attributedTitle overrides.
  upValueLabel.frame=$.NSMakeRect(speedX,9.3,22,10.5);
  upUnitLabel.frame=$.NSMakeRect(speedX+22,9.3,27,10.5);
  downValueLabel.frame=$.NSMakeRect(speedX,0.3,22,10.5);
  downUnitLabel.frame=$.NSMakeRect(speedX+22,0.3,27,10.5);
  upValueLabel.stringValue=$(up.value); upUnitLabel.stringValue=$(up.unit);
  downValueLabel.stringValue=$(down.value); downUnitLabel.stringValue=$(down.unit);
}
function renderStatusButton(){
  if(!statusItem) return;
  var button=statusItem.button;
  try {
    keepMenuVisible();

    if(showSpeed && statusOverlay){
      button.image=null; button.imagePosition=0; button.title='';
      renderStatusSpeedOverlay();
      return;
    }

    setStatusOverlayHidden(true);
    var hasText=showStatus;
    if(showIcon&&appSymbol){
      button.image=appSymbol;
      button.imagePosition=hasText?2:1; // NSImageLeft / NSImageOnly
    } else {
      button.image=null;
      button.imagePosition=0;
    }
    if(!hasText){
      statusItem.length=25;
      button.title='';
      return;
    }
    try{button.font=$.NSFont.systemFontOfSize(9.2);button.alignment=0;}catch(ignore){}
    var state=lastReachable?(lastRunning?'Running':'Stopped'):'Offline';
    button.title=$(state);
    statusItem.length=showIcon?82:60;
  } catch(renderErr) {
    // Never allow a cosmetic status-bar failure to terminate the whole App.
    try{
      setStatusOverlayHidden(true);
      keepMenuVisible();
      if(showStatus||showSpeed){
        button.image=null;
        button.imagePosition=0;
        button.title=$(safeSingleLineTitle());
        statusItem.length=showSpeed?118:62;
      } else {
        button.title='';
        button.image=appSymbol;
        button.imagePosition=1;
        statusItem.length=25;
      }
    }catch(ignore){}
  }
}
function updateStatusTitle(){
  if(!statusItem) return;
  renderStatusButton();
  var state=lastReachable?(lastRunning?'Running':'Stopped'):'Offline';
  if(statusHeader) statusHeader.title='Mihomo Core  ·  '+lastCoreVersion+'  ·  '+state;
  if(speedHeader) speedHeader.title='↑  上传  '+fmtRate(lastUp)+'      ↓  下载  '+fmtRate(lastDown);
  if(startItem) startItem.enabled=lastReachable&&!lastRunning;
  if(stopItem) stopItem.enabled=lastReachable&&lastRunning;
}
function updateStatus(quiet){
  var d=statusFromFile();
  if(d){
    var stamp=Number(d._menu_updated_unix_ms||0);
    if(stamp>0 && (Date.now()-stamp)>5000) d=null;
  }
  if(!d){
    missingSnapshotTicks++;
    // Normal ticks remain file-only. If the snapshot is missing/stale for a few
    // cycles, do one loopback fallback so menu-bar speed can recover itself.
    if(quiet===false || missingSnapshotTicks>=4){d=get('/local/status',quiet===true);missingSnapshotTicks=0;}
  } else missingSnapshotTicks=0;
  if(d){
    lastReachable=true; lastRunning=!!(d.service&&d.service.active); lastUp=Number(d.speed&&d.speed.up||0); lastDown=Number(d.speed&&d.speed.down||0);
    lastCoreVersion=(d.versions&&d.versions.core)||'--';
  } else { lastReachable=false; lastUp=0; lastDown=0; }
  updateStatusTitle();
}
function rebuildServers(){
  if(!serverMenu) return;
  while(serverMenu.numberOfItems>0) serverMenu.removeItemAtIndex(0);
  var d=get('/local/profiles',true); if(!d||!d.profiles) return;
  var selectedName='未选择';
  d.profiles.forEach(function(p){
    var i=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent(p.name,'selectProfile:',''); i.target=delegate; i.representedObject=$(p.id); i.state=(p.id===d.selectedID)?1:0; serverMenu.addItem(i);
    if(p.id===d.selectedID) selectedName=p.name;
  });
  if(serverRoot) serverRoot.title='服务器  ·  '+selectedName;
}

function samplesDelay(samples){
  if(!Array.isArray(samples)||!samples.length) return null;
  for(var i=samples.length-1;i>=0;i--){var d=Number((samples[i]||{}).delay);if(isFinite(d))return d;}
  return null;
}
function menuExtraHistory(value){
  if(Array.isArray(value))return value;
  if(value&&Array.isArray(value.history))return value.history;
  return [];
}
function menuResolvedProxyName(name){
  var current=String(name||''), seen={};
  while(current && proxyMenuData[current] && proxyMenuData[current].now && String(proxyMenuData[current].now)!==current){
    if(seen[current])break;
    seen[current]=true;
    var next=String(proxyMenuData[current].now||'');
    if(!proxyMenuData[next])break;
    current=next;
  }
  return current||String(name||'');
}
function menuProxyDelay(p, preferredUrl){
  if(!p) return null;
  var failed=false;

  // MetaCubeXD/Mihomo semantics: a zero is NOT_CONNECTED for that URL. Keep
  // looking for a positive measurement from another URL before showing timeout.
  if(Object.prototype.hasOwnProperty.call(p,'lastTestDelay')){
    var x=Number(p.lastTestDelay);
    if(isFinite(x)&&x>0)return x;
    if(isFinite(x))failed=true;
  }

  if(preferredUrl&&p.extra){
    var pd=samplesDelay(menuExtraHistory(p.extra[preferredUrl]));
    if(pd!==null&&pd>0)return pd;
    if(pd!==null)failed=true;
  }

  if(p.extra&&typeof p.extra==='object'){
    var keys=Object.keys(p.extra);
    for(var k=0;k<keys.length;k++){
      var d=samplesDelay(menuExtraHistory(p.extra[keys[k]]));
      if(d!==null&&d>0)return d;
      if(d!==null)failed=true;
    }
  }

  var legacy=samplesDelay(p.history);
  if(legacy!==null&&legacy>0)return legacy;
  if(legacy!==null)failed=true;
  return failed?0:null;
}
function menuProxyDelayText(p, preferredUrl){
  var d=menuProxyDelay(p,preferredUrl); if(d===null) return ''; if(d<=0) return '超时'; return d+' ms';
}
function proxyConfigOrderedGroups(data){
  var groups=Object.keys(data||{}).filter(function(name){
    var p=data[name]; return p&&Array.isArray(p.all)&&p.all.length&&p.hidden!==true;
  });
  var order=(data&&data.GLOBAL&&Array.isArray(data.GLOBAL.all))?data.GLOBAL.all:[], positions={};
  order.forEach(function(name,index){positions[name]=index;});
  groups.sort(function(a,b){
    if(a==='GLOBAL'&&b!=='GLOBAL')return 1;
    if(b==='GLOBAL'&&a!=='GLOBAL')return -1;
    var ai=Object.prototype.hasOwnProperty.call(positions,a)?positions[a]:2147483647;
    var bi=Object.prototype.hasOwnProperty.call(positions,b)?positions[b]:2147483647;
    if(ai!==bi)return ai-bi;
    return a.localeCompare(b);
  });
  return groups;
}
function buildProxySubmenu(sub){
  if(!sub)return;
  var group=ObjC.unwrap(sub.title), p=proxyMenuData[group];
  if(!p)return;
  var key=String(proxyMenuGeneration)+':'+group;
  if(proxySubmenuBuilt[key])return;

  while(sub.numberOfItems>0)sub.removeItemAtIndex(0);
  var test=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('测速此组','testProxyGroupMenu:','');
  test.target=delegate; test.representedObject=$(group); addSymbol(test,'gauge.with.dots.needle.33percent'); sub.addItem(test);
  sub.addItem($.NSMenuItem.separatorItem);

  var selectable=['selector','urltest','fallback'].indexOf(String(p.type||'').toLowerCase())>=0;
  if(selectable){
    (p.all||[]).forEach(function(proxyName){
      var resolved=menuResolvedProxyName(proxyName);
      var node=proxyMenuData[resolved]||proxyMenuData[proxyName]||{}, delay=menuProxyDelayText(node,p.testUrl||'');
      var nodeTitle=proxyName+(delay?'  ·  '+delay:'');
      var item=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent(nodeTitle,'selectProxyMenu:','');
      item.target=delegate; item.representedObject=$(JSON.stringify({group:group,name:proxyName}));
      item.state=(p.now===proxyName)?1:0;
      sub.addItem(item);
    });
  }else{
    var automatic=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('自动策略组，不支持手动选择','','');
    automatic.enabled=false; sub.addItem(automatic);
  }

  sub.addItem($.NSMenuItem.separatorItem);
  var open=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('打开代理切换…','proxies:','');
  open.target=delegate; addSymbol(open,'macwindow'); sub.addItem(open);
  proxySubmenuBuilt[key]=true;
}
function rebuildProxyMenus(){
  if(!menu||!coreRoot)return;
  // Read the Go-side atomic snapshot directly from disk. No curl, no process
  // spawn, and no remote controller request can run on AppKit's menu event loop.
  var data=proxyMenuFromFile(); if(!data||!data.proxies)return;
  var generation=Number(data.generation||0);
  if(generation===proxyMenuGeneration)return;

  proxyMenuGeneration=generation;
  proxyMenuData=data.proxies||{};
  proxySubmenuBuilt={};

  proxyMenuRoots.forEach(function(root){try{menu.removeItem(root);}catch(e){}});
  proxyMenuRoots=[];

  var groups=proxyConfigOrderedGroups(proxyMenuData);
  var index=proxyEndSeparator?menu.indexOfItem(proxyEndSeparator):menu.indexOfItem(coreRoot); if(index<0)index=menu.numberOfItems;
  groups.forEach(function(name){
    var p=proxyMenuData[name], current=p.now||p.type||'';
    var title=name+(current?'  ·  '+current:'');
    var root=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent(title,'','');
    var sub=$.NSMenu.alloc.initWithTitle(name);
    // A one-item placeholder keeps the submenu affordance visible. Real node
    // items are created lazily only when this one group is opened.
    var loading=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('载入线路…','','');
    loading.enabled=false; sub.addItem(loading); sub.delegate=delegate;
    root.submenu=sub;
    // No synthetic SF Symbol here: user proxy-group names often already start
    // with a flag/emoji and the extra icon made the tray visually noisy.
    menu.insertItemAtIndex(root,index); index++;
    proxyMenuRoots.push(root);
  });
}
ObjC.registerSubclass({name:'MihomoMenuDelegate', methods:{
'openManager:':{types:['void',['id']],implementation:function(){showURL(BASE+'/');}},
'refresh:':{types:['void',['id']],implementation:function(){updateStatus(false);openHash('overview');}},
'tick:':{types:['void',['id']],implementation:function(){updateStatus(true);proxyMenuTick++;if(proxyMenuTick%%3===0){try{rebuildProxyMenus();}catch(e){}}}},
'menuWillOpen:':{types:['void',['id']],implementation:function(sender){}},
'menuNeedsUpdate:':{types:['void',['id']],implementation:function(sender){try{buildProxySubmenu(sender);}catch(e){}}},
'toggleShowIcon:':{types:['void',['id']],implementation:function(){showIcon=!showIcon;keepMenuVisible();savePrefs();syncPrefItems();updateStatusTitle();}},
'toggleShowStatus:':{types:['void',['id']],implementation:function(){showStatus=!showStatus;keepMenuVisible();savePrefs();syncPrefItems();updateStatusTitle();}},
'toggleShowSpeed:':{types:['void',['id']],implementation:function(){showSpeed=!showSpeed;keepMenuVisible();savePrefs();syncPrefItems();updateStatusTitle();}},
'iconOnly:':{types:['void',['id']],implementation:function(){showIcon=true;showStatus=false;showSpeed=false;savePrefs();syncPrefItems();updateStatusTitle();}},
'selectProfile:':{types:['void',['id']],implementation:function(sender){var id=ObjC.unwrap(sender.representedObject);if(post('/local/profile/select',{id:id},false)){proxyMenuGeneration=-1;proxySubmenuBuilt={};rebuildServers();updateStatus(true);openHash('overview');}}},
'startCore:':{types:['void',['id']],implementation:function(){if(post('/local/action',{action:'start'},false)){updateStatus(true);}}},
'stopCore:':{types:['void',['id']],implementation:function(){if(post('/local/action',{action:'stop'},false)){updateStatus(true);}}},
'restartCore:':{types:['void',['id']],implementation:function(){if(post('/local/action',{action:'restart'},false)){updateStatus(true);}}},
'reloadConfig:':{types:['void',['id']],implementation:function(){post('/local/reload-config',{},false);}},
'applySubs:':{types:['void',['id']],implementation:function(){post('/local/action',{action:'apply_subscriptions'},false);}},
'proxies:':{types:['void',['id']],implementation:function(){openHash('proxies');}},
'testProxyGroupMenu:':{types:['void',['id']],implementation:function(sender){
  var group=ObjC.unwrap(sender.representedObject), p=proxyMenuData[group]||{};
  var d=post('/local/proxy-delay-async',{group:group,url:p.testUrl||'',expected:p.expectedStatus||'',timeout:5000},false);
  if(d)std.displayNotification('已开始测速“'+group+'”',{withTitle:'Mihomo Core Manager'});
}},
'selectProxyMenu:':{types:['void',['id']],implementation:function(sender){
  try{
    var payload=JSON.parse(ObjC.unwrap(sender.representedObject));
    if(post('/local/proxy-select-async',payload,false)){
      if(proxyMenuData[payload.group])proxyMenuData[payload.group].now=payload.name;
      proxySubmenuBuilt={};
    }
  }catch(e){std.displayNotification(String(e),{withTitle:'Mihomo Core Manager'});}
}},

'subscriptions:':{types:['void',['id']],implementation:function(){openHash('subscriptions');}},
'logs:':{types:['void',['id']],implementation:function(){openHash('logs');}},
'checkUpdate:':{types:['void',['id']],implementation:function(){openHash('updates');}},
'applyUpdate:':{types:['void',['id']],implementation:function(){post('/local/update/apply',{},false);openHash('updates');}},
'openMeta:':{types:['void',['id']],implementation:function(){var o=get('/local/metacubexd',false);if(o&&o.url)post('/local/open-url',{url:o.url},false);}},
'settings:':{types:['void',['id']],implementation:function(){openHash('settings');}},
'quitApp:':{types:['void',['id']],implementation:function(){post('/local/quit',{},true);$.NSApplication.sharedApplication.terminate(null);}}
}});
var delegate=$.MihomoMenuDelegate.alloc.init;

// Standard Edit menu keeps Command-C / Command-V / Command-A on the WebKit responder chain.
var mainMenu=$.NSMenu.alloc.init;
var appRoot=$.NSMenuItem.alloc.init, appMenu=$.NSMenu.alloc.initWithTitle('Mihomo Core Manager');
appMenu.addItem($.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('关于 Mihomo Core Manager','orderFrontStandardAboutPanel:',''));
appMenu.addItem($.NSMenuItem.separatorItem);
var quitMain=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('退出 Mihomo Core Manager','quitApp:','q'); quitMain.target=delegate; appMenu.addItem(quitMain);
appRoot.submenu=appMenu; mainMenu.addItem(appRoot);
var editRoot=$.NSMenuItem.alloc.init, editMenu=$.NSMenu.alloc.initWithTitle('编辑');
function editItem(title,sel,key){var i=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent(title,sel,key);editMenu.addItem(i);return i;}
editItem('撤销','undo:','z'); editMenu.addItem($.NSMenuItem.separatorItem); editItem('剪切','cut:','x'); editItem('复制','copy:','c'); editItem('粘贴','paste:','v'); editItem('全选','selectAll:','a');
editRoot.submenu=editMenu; mainMenu.addItem(editRoot); cocoaApp.mainMenu=mainMenu;

statusItem=$.NSStatusBar.systemStatusBar.statusItemWithLength(25); statusItem.button.toolTip='Mihomo Core Manager v%s';
try{appSymbol=$.NSImage.imageWithSystemSymbolNameAccessibilityDescription('circle.grid.cross','Mihomo Core');appSymbol.template=true;}catch(e){}
try{
  statusOverlay=$.MihomoStatusOverlayView.alloc.initWithFrame($.NSMakeRect(0,0,25,22));
  statusIconView=$.MihomoStatusIconView.alloc.initWithFrame($.NSMakeRect(3,4,14,14));
  statusIconView.imageScaling=3; statusOverlay.addSubview(statusIconView);
  function makeStatusLabel(size,weight){
    var label=$.MihomoStatusLabel.alloc.initWithFrame($.NSMakeRect(0,0,1,1));
    label.stringValue=''; label.bezeled=false; label.bordered=false; label.drawsBackground=false; label.editable=false; label.selectable=false;
    try{label.font=$.NSFont.monospacedSystemFontOfSizeWeight(size,weight);}catch(e){label.font=$.NSFont.systemFontOfSize(size);}
    label.alignment=0; label.textColor=$.NSColor.labelColor;
    return label;
  }
  upValueLabel=makeStatusLabel(8.5,0.28); upUnitLabel=makeStatusLabel(8.5,0.28);
  downValueLabel=makeStatusLabel(8.5,0.28); downUnitLabel=makeStatusLabel(8.5,0.28);
  statusDot=makeStatusLabel(5.5,0.0); statusDot.stringValue='●';
  statusOverlay.addSubview(upValueLabel); statusOverlay.addSubview(upUnitLabel);
  statusOverlay.addSubview(downValueLabel); statusOverlay.addSubview(downUnitLabel); statusOverlay.addSubview(statusDot);
  statusItem.button.addSubview(statusOverlay);
}catch(overlayErr){statusOverlay=null;}

var prefs=get('/local/menu-preferences',true); if(prefs){showIcon=prefs.showIcon!==false;showStatus=!!prefs.showStatus;showSpeed=!!prefs.showSpeed;} keepMenuVisible();
var menu=$.NSMenu.alloc.init;
menu.autoenablesItems=false;
function addItem(targetMenu,title,sel,key){var i=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent(title,sel,key||'');i.target=delegate;targetMenu.addItem(i);return i;}
function addSymbol(item,name){try{var img=$.NSImage.imageWithSystemSymbolNameAccessibilityDescription(name,item.title);if(img){img.template=true;item.image=img;}}catch(e){} return item;}
function addSep(targetMenu){targetMenu.addItem($.NSMenuItem.separatorItem);}

statusHeader=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('Mihomo Core  ·  --  ·  Offline','', '');statusHeader.enabled=false;menu.addItem(statusHeader);
speedHeader=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('↑  上传  0 B/s      ↓  下载  0 B/s','', '');speedHeader.enabled=false;menu.addItem(speedHeader);
addSep(menu);

addSymbol(addItem(menu,'打开主窗口','openManager:','o'),'macwindow');
addSymbol(addItem(menu,'刷新状态','refresh:','r'),'arrow.clockwise');
serverRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('服务器  ·  未选择','', ''); serverMenu=$.NSMenu.alloc.initWithTitle('服务器'); serverRoot.submenu=serverMenu; addSymbol(serverRoot,'server.rack'); menu.addItem(serverRoot); rebuildServers();
addSep(menu);

proxyHeader=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('代理组','',''); proxyHeader.enabled=false; menu.addItem(proxyHeader);
proxyEndSeparator=$.NSMenuItem.separatorItem; menu.addItem(proxyEndSeparator);
var coreRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('Core 控制','', ''); var coreMenu=$.NSMenu.alloc.initWithTitle('Core 控制'); coreRoot.submenu=coreMenu; addSymbol(coreRoot,'cpu'); menu.addItem(coreRoot);
startItem=addSymbol(addItem(coreMenu,'启动 Core','startCore:',''),'play.fill');
stopItem=addSymbol(addItem(coreMenu,'停止 Core','stopCore:',''),'stop.fill');
addSymbol(addItem(coreMenu,'重启 Core','restartCore:',''),'arrow.clockwise');
addSymbol(addItem(coreMenu,'重载配置','reloadConfig:',''),'doc.badge.arrow.up');
addSep(coreMenu);
addSymbol(addItem(coreMenu,'应用订阅 + 热重载','applySubs:',''),'arrow.triangle.2.circlepath');

var toolsRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('管理与工具','', ''); var toolsMenu=$.NSMenu.alloc.initWithTitle('管理与工具'); toolsRoot.submenu=toolsMenu; addSymbol(toolsRoot,'square.grid.2x2'); menu.addItem(toolsRoot);
addSymbol(addItem(toolsMenu,'订阅管理…','subscriptions:',''),'arrow.left.arrow.right');
addSymbol(addItem(toolsMenu,'运行日志…','logs:',''),'text.alignleft');
addSymbol(addItem(toolsMenu,'项目升级…','checkUpdate:',''),'arrow.up.circle');
addSymbol(addItem(toolsMenu,'开始项目升级','applyUpdate:',''),'arrow.down.circle');
addSymbol(addItem(toolsMenu,'打开 MetaCubeXD','openMeta:',''),'safari');

var displayRoot=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('状态栏显示','', ''); var displayMenu=$.NSMenu.alloc.initWithTitle('状态栏显示'); displayRoot.submenu=displayMenu; addSymbol(displayRoot,'menubar.rectangle'); menu.addItem(displayRoot);
prefIconItem=addItem(displayMenu,'显示图标','toggleShowIcon:',''); prefStatusItem=addItem(displayMenu,'显示运行状态','toggleShowStatus:',''); prefSpeedItem=addItem(displayMenu,'显示网速','toggleShowSpeed:',''); addSep(displayMenu); iconOnlyItem=addItem(displayMenu,'仅显示图标','iconOnly:',''); syncPrefItems();
addSep(menu);
addSymbol(addItem(menu,'设置…','settings:',','),'gearshape');
addSymbol(addItem(menu,'退出 Mihomo Core Manager','quitApp:','q'),'power');
menu.delegate=delegate;
rebuildProxyMenus();
statusItem.menu=menu;
updateStatus(true);
$.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(1.2,delegate,'tick:',null,true);
showURL(BASE+'/'); cocoaApp.run;
`, base, token, statusFile, appVersion)
}

func fallbackMenuScript(base string) string {
	// Minimal recovery shell. It intentionally avoids custom status-bar text
	// rendering so a JXA/AppKit compatibility issue cannot make the App flash-quit.
	return fmt.Sprintf(`ObjC.import('Cocoa'); ObjC.import('WebKit');
var BASE=%q;
var app=$.NSApplication.sharedApplication; app.setActivationPolicy(1);
var rect=$.NSMakeRect(0,0,1180,760);
var win=$.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(rect,32783,2,false);
win.title='Mihomo Core 管理面板'; win.titleVisibility=1; win.titlebarAppearsTransparent=true; win.movableByWindowBackground=true;
var web=$.WKWebView.alloc.initWithFrame(win.contentView.bounds); web.autoresizingMask=18; win.contentView.addSubview(web);
function show(){var u=$.NSURL.URLWithString($(BASE+'/'));web.loadRequest($.NSURLRequest.requestWithURL(u));win.center;win.makeKeyAndOrderFront(null);app.activateIgnoringOtherApps(true);}
ObjC.registerSubclass({name:'MihomoRecoveryDelegate',methods:{
'open:':{types:['void',['id']],implementation:function(){show();}},
'quit:':{types:['void',['id']],implementation:function(){$.NSApplication.sharedApplication.terminate(null);}}
}});
var delegate=$.MihomoRecoveryDelegate.alloc.init;
var item=$.NSStatusBar.systemStatusBar.statusItemWithLength(25);
try{var img=$.NSImage.imageWithSystemSymbolNameAccessibilityDescription('circle.grid.cross','Mihomo Core');img.template=true;item.button.image=img;}catch(e){item.button.title='M';}
item.button.toolTip='Mihomo Core Manager recovery mode';
var menu=$.NSMenu.alloc.init;
var note=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('恢复模式：状态栏渲染已降级','','');note.enabled=false;menu.addItem(note);menu.addItem($.NSMenuItem.separatorItem);
var open=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('打开主窗口…','open:','');open.target=delegate;menu.addItem(open);
var quit=$.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('退出','quit:','q');quit.target=delegate;menu.addItem(quit);item.menu=menu;
show(); app.run;
`, base)
}

func appDone(s *appState) bool {
	select {
	case <-s.done:
		return true
	default:
		return false
	}
}

func startJXA(scriptPath, logPath string) (*exec.Cmd, error) {
	cmd := exec.Command("/usr/bin/osascript", "-l", "JavaScript", scriptPath)
	if f, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600); err == nil {
		_, _ = fmt.Fprintf(f, "\n[%s] launch %s\n", time.Now().Format(time.RFC3339), filepath.Base(scriptPath))
		cmd.Stdout = f
		cmd.Stderr = f
	} else {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	return cmd, nil
}

func launchMenu(base string, s *appState) error {
	dir := filepath.Join(filepath.Dir(s.path), "Runtime")
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	script := filepath.Join(dir, "menubar.js")
	fallback := filepath.Join(dir, "menubar-recovery.js")
	logPath := filepath.Join(dir, "menubar.log")
	if err := os.WriteFile(script, []byte(menuScript(base, s.token, s.statusFilePath())), 0600); err != nil {
		return err
	}
	if err := os.WriteFile(fallback, []byte(fallbackMenuScript(base)), 0600); err != nil {
		return err
	}
	cmd, err := startJXA(script, logPath)
	if err != nil {
		return err
	}
	go func() {
		err := cmd.Wait()
		if appDone(s) {
			return
		}
		log.Printf("menu shell exited (%v); starting recovery shell", err)
		recovery, startErr := startJXA(fallback, logPath)
		if startErr != nil {
			log.Printf("menu recovery: %v", startErr)
			s.doneOnce.Do(func() { close(s.done) })
			return
		}
		_ = recovery.Wait()
		if !appDone(s) {
			s.doneOnce.Do(func() { close(s.done) })
		}
	}()
	return nil
}

func main() {
	if runtime.GOOS != "darwin" || runtime.GOARCH != "arm64" {
		log.Printf("warning: build target is %s/%s; release target is darwin/arm64", runtime.GOOS, runtime.GOARCH)
	}
	s := loadState()
	ln, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		log.Fatal(err)
	}
	base := "http://" + ln.Addr().String()
	s.server = &http.Server{Handler: s.routes(), ReadHeaderTimeout: 5 * time.Second}
	go func() {
		if err := s.server.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("server: %v", err)
		}
	}()
	s.startStatusPoller()
	s.startProxyMenuPoller()
	if runtime.GOOS == "darwin" {
		if err := launchMenu(base, s); err != nil {
			log.Printf("menu: %v", err)
		}
	}
	<-s.done
}
