// Package xraymobile is a small, from-scratch, MPL-2.0-compatible wrapper
// around xtls/xray-core, built for gomobile bind on iOS/macOS/tvOS.
//
// It intentionally does not reuse any code from github.com/2dust/AndroidLibXrayLite
// (LGPLv3) or github.com/v2fly/v2ray-core's own Android bindings — only the
// *pattern* of embedding xray-core's core.Instance was studied from those
// projects as prior art, and this file is an independent implementation
// against xray-core's own public Go API (core.New, core.Instance.Start/Close,
// infra/conf/serial.LoadJSONConfig, features/stats.Manager).
//
// It replaces HushTunnel's prior sing-box (GPLv3) engine. xray-core itself is
// MPL-2.0, which — unlike GPLv3 — has no App Store-incompatible "installation
// information" requirement, and is what HushTunnel's VPN nodes already run
// server-side (via 3x-ui), so no server-side changes are required.
package xraymobile

import (
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"sync"

	core "github.com/xtls/xray-core/core"
	corestats "github.com/xtls/xray-core/features/stats"
	coreserial "github.com/xtls/xray-core/infra/conf/serial"

	// Registers all of xray-core's built-in inbound/outbound/transport
	// handlers (vless, freedom, socks, reality TLS, etc.) via side-effect
	// init(), exactly as xray-core's own main package does.
	_ "github.com/xtls/xray-core/main/distro/all"
)

// Engine owns a single xray-core instance. It is safe for concurrent use.
// gomobile bind exposes this as an opaque reference type to Swift; only the
// exported methods below are callable from the Swift side.
type Engine struct {
	mu        sync.Mutex
	instance  *core.Instance
	running   bool
	lastError string
}

// NewEngine constructs an idle Engine. Exported as a gomobile-bind
// constructor (XraymobileNewEngine() in the generated Objective-C/Swift API).
func NewEngine() *Engine {
	return &Engine{}
}

// Start parses a standard vless:// subscription link (the same format
// HushTunnel's backend already serves as its default/fallback subscription
// format — see server-links.ts:buildVlessLink on the backend) and starts a
// local xray-core instance with:
//   - one outbound ("proxy"): the parsed VLESS+REALITY+XTLS-Vision route
//   - one outbound ("direct"): freedom, used for routing exceptions (none by
//     default — see Config() below)
//   - one inbound: a loopback SOCKS5 proxy on 127.0.0.1:<socksPort>, which
//     HevSocks5Tunnel (the tun2socks layer) connects to.
//
// socksPort should be a high, unprivileged, loopback-only port chosen by the
// caller (e.g. 1089) that does not collide with anything else in the
// Network Extension process.
//
// Start blocks only long enough to validate the config and start xray-core's
// internal workers; it does not block for the lifetime of the tunnel (unlike
// hev_socks5_tunnel_main, which does). Returns a non-nil error, and leaves
// the Engine in a stopped state, on any failure.
func (e *Engine) Start(vlessLink string, socksPort int) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.running {
		return fmt.Errorf("xraymobile: engine already running")
	}

	route, err := parseVlessLink(vlessLink)
	if err != nil {
		e.lastError = err.Error()
		return fmt.Errorf("xraymobile: parse vless link: %w", err)
	}

	cfgJSON, err := buildConfigJSON(route, socksPort)
	if err != nil {
		e.lastError = err.Error()
		return fmt.Errorf("xraymobile: build config: %w", err)
	}

	config, err := coreserial.LoadJSONConfig(strings.NewReader(cfgJSON))
	if err != nil {
		e.lastError = err.Error()
		return fmt.Errorf("xraymobile: load config: %w", err)
	}

	instance, err := core.New(config)
	if err != nil {
		e.lastError = err.Error()
		return fmt.Errorf("xraymobile: core.New: %w", err)
	}

	if err := instance.Start(); err != nil {
		e.lastError = err.Error()
		return fmt.Errorf("xraymobile: core start: %w", err)
	}

	e.instance = instance
	e.running = true
	e.lastError = ""
	return nil
}

// Stop tears down the running xray-core instance, if any. Idempotent: safe
// to call when already stopped (returns nil).
func (e *Engine) Stop() error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if !e.running || e.instance == nil {
		e.running = false
		e.instance = nil
		return nil
	}

	err := e.instance.Close()
	e.instance = nil
	e.running = false
	if err != nil {
		return fmt.Errorf("xraymobile: core close: %w", err)
	}
	return nil
}

// IsRunning reports whether an xray-core instance is currently active.
func (e *Engine) IsRunning() bool {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.running
}

// LastError returns the error string from the most recent failed Start, or
// "" if the last Start succeeded or none has been attempted. Exists because
// gomobile bind's generated Swift API can't propagate a Go `error` out of a
// context other than a direct method return, and callers sometimes want to
// inspect this asynchronously (e.g. after a crash-recovery restart).
func (e *Engine) LastError() string {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.lastError
}

// statsTag must match the outbound "tag" used in buildConfigJSON.
const statsTag = "proxy"

// StatsJSON returns `{"uplink":<bytes>,"downlink":<bytes>}` for the proxy
// outbound's cumulative traffic counters, or all-zero if the engine isn't
// running or stats aren't available yet. A single JSON string (rather than a
// struct) is used because it is trivially representable in gomobile bind's
// generated Swift API without needing a custom bound type.
func (e *Engine) StatsJSON() string {
	e.mu.Lock()
	instance := e.instance
	e.mu.Unlock()

	up, down := int64(0), int64(0)
	if instance != nil {
		if f := instance.GetFeature(corestats.ManagerType()); f != nil {
			if manager, ok := f.(corestats.Manager); ok {
				if c := manager.GetCounter("outbound>>>" + statsTag + ">>>traffic>>>uplink"); c != nil {
					up = c.Value()
				}
				if c := manager.GetCounter("outbound>>>" + statsTag + ">>>traffic>>>downlink"); c != nil {
					down = c.Value()
				}
			}
		}
	}

	b, _ := json.Marshal(struct {
		Uplink   int64 `json:"uplink"`
		Downlink int64 `json:"downlink"`
	}{up, down})
	return string(b)
}

// Version returns the embedded xray-core version string, for diagnostics /
// the app's "Debug Logs" screen.
func Version() string {
	return core.Version()
}

// --- vless:// link parsing -------------------------------------------------

// vlessRoute is the subset of a parsed vless:// link this engine needs.
// Field names mirror the query parameters HushTunnel's backend emits in
// server-links.ts:buildVlessLink, which in turn follow the community-
// standard VLESS share-link convention used by v2rayN/NekoBox/Shadowrocket/
// v2rayNG (HushTunnel's own Android client).
type vlessRoute struct {
	UUID        string // userinfo
	Host        string
	Port        uint16
	Encryption  string // query: encryption (defaults to "none" if absent)
	Flow        string // query: flow (e.g. "xtls-rprx-vision")
	Security    string // query: security ("reality" or "tls")
	SNI         string // query: sni
	Fingerprint string // query: fp
	PublicKey   string // query: pbk (reality only)
	ShortID     string // query: sid (reality only)
	SpiderX     string // query: spx (reality only)
	Network     string // query: type (e.g. "tcp")
}

func parseVlessLink(link string) (*vlessRoute, error) {
	u, err := url.Parse(strings.TrimSpace(link))
	if err != nil {
		return nil, fmt.Errorf("invalid vless url: %w", err)
	}
	if u.Scheme != "vless" {
		return nil, fmt.Errorf("not a vless:// link (scheme=%q)", u.Scheme)
	}
	if u.User == nil || u.User.Username() == "" {
		return nil, fmt.Errorf("vless link missing uuid")
	}
	if u.Hostname() == "" {
		return nil, fmt.Errorf("vless link missing host")
	}
	portStr := u.Port()
	if portStr == "" {
		return nil, fmt.Errorf("vless link missing port")
	}
	port64, err := strconv.ParseUint(portStr, 10, 16)
	if err != nil {
		return nil, fmt.Errorf("invalid port %q: %w", portStr, err)
	}

	q := u.Query()
	route := &vlessRoute{
		UUID:        u.User.Username(),
		Host:        u.Hostname(),
		Port:        uint16(port64),
		Encryption:  firstNonEmpty(q.Get("encryption"), "none"),
		Flow:        q.Get("flow"),
		Security:    firstNonEmpty(q.Get("security"), "none"),
		SNI:         q.Get("sni"),
		Fingerprint: q.Get("fp"),
		PublicKey:   q.Get("pbk"),
		ShortID:     q.Get("sid"),
		SpiderX:     q.Get("spx"),
		Network:     firstNonEmpty(q.Get("type"), "tcp"),
	}

	if route.Security == "reality" && route.PublicKey == "" {
		return nil, fmt.Errorf("reality security requires pbk (publicKey)")
	}

	return route, nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// --- Xray-core JSON config construction -------------------------------------

// buildConfigJSON renders the full xray-core JSON config: one VLESS+REALITY
// outbound (tag "proxy") carrying all traffic, one freedom outbound (tag
// "direct", currently unused by any routing rule but present so future
// split-tunnel rules have somewhere to route to without a config change),
// one loopback SOCKS5 inbound for HevSocks5Tunnel, and stats/policy blocks
// enabling the uplink/downlink counters StatsJSON reads.
//
// JSON field names below are verified against xray-core's own
// infra/conf/vless.go (VLessOutboundConfig/VLessOutboundVnext) and
// infra/conf/transport_security.go (REALITYConfig) for this exact pinned
// xray-core version — don't rename fields without re-checking those against
// whatever version this module is bumped to.
func buildConfigJSON(route *vlessRoute, socksPort int) (string, error) {
	if socksPort <= 0 || socksPort > 65535 {
		return "", fmt.Errorf("invalid socksPort %d", socksPort)
	}

	user := map[string]any{
		"id":         route.UUID,
		"encryption": route.Encryption,
	}
	if route.Flow != "" {
		user["flow"] = route.Flow
	}

	streamSettings := map[string]any{
		"network":  route.Network,
		"security": route.Security,
	}
	switch route.Security {
	case "reality":
		streamSettings["realitySettings"] = map[string]any{
			"serverName":  route.SNI,
			"fingerprint": firstNonEmpty(route.Fingerprint, "chrome"),
			"publicKey":   route.PublicKey,
			"shortId":     route.ShortID,
			"spiderX":     firstNonEmpty(route.SpiderX, "/"),
		}
	case "tls":
		streamSettings["tlsSettings"] = map[string]any{
			"serverName":  route.SNI,
			"fingerprint": firstNonEmpty(route.Fingerprint, "chrome"),
		}
	case "none", "":
		// plaintext — no extra stream settings block
	default:
		return "", fmt.Errorf("unsupported security %q", route.Security)
	}

	cfg := map[string]any{
		"log": map[string]any{
			"loglevel": "warning",
		},
		"stats": map[string]any{},
		"policy": map[string]any{
			"levels": map[string]any{
				"0": map[string]any{
					"statsUserUplink":   true,
					"statsUserDownlink": true,
				},
			},
			"system": map[string]any{
				"statsOutboundUplink":   true,
				"statsOutboundDownlink": true,
			},
		},
		"inbounds": []map[string]any{
			{
				"tag":      "socks-in",
				"listen":   "127.0.0.1",
				"port":     socksPort,
				"protocol": "socks",
				"settings": map[string]any{
					"udp":  true,
					"auth": "noauth",
				},
				"sniffing": map[string]any{
					"enabled":      true,
					"destOverride": []string{"http", "tls"},
				},
			},
		},
		"outbounds": []map[string]any{
			{
				"tag":      statsTag,
				"protocol": "vless",
				"settings": map[string]any{
					"vnext": []map[string]any{
						{
							"address": route.Host,
							"port":    route.Port,
							"users":   []map[string]any{user},
						},
					},
				},
				"streamSettings": streamSettings,
			},
			{
				"tag":      "direct",
				"protocol": "freedom",
			},
			{
				"tag":      "block",
				"protocol": "blackhole",
			},
		},
		"routing": map[string]any{
			"domainStrategy": "AsIs",
			"rules": []map[string]any{
				{
					"type":        "field",
					"inboundTag":  []string{"socks-in"},
					"outboundTag": statsTag,
				},
			},
		},
	}

	b, err := json.Marshal(cfg)
	if err != nil {
		return "", fmt.Errorf("marshal config: %w", err)
	}
	return string(b), nil
}
