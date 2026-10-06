import Foundation
import HevSocks5Tunnel
import Library
import NetworkExtension
import XrayMobile
import os.log

/// HushTunnel iOS's Network Extension entry point.
///
/// Replaces the former sing-box (GPLv3, via `Library/Network/ExtensionProvider.swift`)
/// engine with xray-core (MPL-2.0) + hev-socks5-tunnel (MIT), because GPLv3 is
/// legally incompatible with App Store distribution. macOS and tvOS (SFM/SFT)
/// are untouched and continue to use `ExtensionProvider`/sing-box — this class
/// does not subclass or share code with it; it implements `NEPacketTunnelProvider`
/// directly.
///
/// Architecture (verified against real prior art, not guessed):
///   TUN (utun, via NEPacketTunnelNetworkSettings) ←→ hev-socks5-tunnel ←→
///   loopback SOCKS5 (127.0.0.1:socksPort) ←→ xray-core ←→ VLESS+REALITY+XTLS-Vision
///   ←→ HushTunnel's VPN node (already running xray-core server-side, via 3x-ui).
///
/// This is the same architecture HushTunnel's own Android client already ships
/// (HushTunnel-Android-Client/.../TProxyService.kt + AndroidLibXrayLite — not
/// code shared with this file, just the same two upstream libraries, studied as
/// prior art). The technique for obtaining the raw tun fd from
/// `NEPacketTunnelFlow` (not otherwise exposed as a POSIX fd on Apple platforms)
/// is the same KVC lookup already used — and proven, in production — by this
/// repo's own `ExtensionPlatformInterface.openTun0` for the sing-box engine.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private static let logger = Logger(category: "PacketTunnelProvider")

    /// Loopback-only, unprivileged port xray-core's SOCKS5 inbound listens on.
    /// hev-socks5-tunnel is configured to dial this same port. Arbitrary but
    /// fixed — this process never has another consumer of this port.
    private let socksPort = 1089

    private var engine: XraymobileEngine?
    private var hevThread: Thread?
    private let hevStoppedSemaphore = DispatchSemaphore(value: 0)
    private var tunFd: Int32 = -1
    private var currentVlessLink: String?

    // MARK: - NEPacketTunnelProvider lifecycle

    override func startTunnel(options: [String: NSObject]?) async throws {
        let vlessLink = try resolveVlessLink(options: options)
        Self.logger.info("(packet-tunnel) starting, xray-core \(XraymobileVersion())")
        try await bringUp(vlessLink: vlessLink)
        currentVlessLink = vlessLink
        Self.logger.info("(packet-tunnel) started")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        Self.logger.info("(packet-tunnel) stopping, reason: \(String(describing: reason))")
        await tearDown()
    }

    /// Handles two kinds of app-initiated messages, distinguished by prefix:
    ///   - "vless://..." — switch server while connected (see `reload`).
    ///   - anything else — currently unused; reserved for future control
    ///     messages (e.g. a stats refresh trigger), matching the sing-box
    ///     provider's `handleAppMessage` convention of returning nil on success
    ///     and the UTF-8 error description on failure.
    override func handleAppMessage(_ messageData: Data) async -> Data? {
        guard let message = String(data: messageData, encoding: .utf8) else {
            return "invalid message encoding".data(using: .utf8)
        }
        if message.hasPrefix("vless://") {
            do {
                try await reload(vlessLink: message)
                return nil
            } catch {
                return error.localizedDescription.data(using: .utf8)
            }
        }
        if message == "stats" {
            return engine?.statsJSON().data(using: .utf8)
        }
        return "unrecognized message".data(using: .utf8)
    }

    override func sleep() async {
        // Unlike the sing-box provider (which pauses its command server here),
        // xray-core and hev-socks5-tunnel have no explicit sleep/wake hooks —
        // their event loops are not driven by anything this process needs to
        // quiesce for system sleep. Intentionally a no-op.
    }

    override func wake() {
        // See sleep() above.
    }

    // MARK: - Tunnel options

    private func resolveVlessLink(options: [String: NSObject]?) throws -> String {
        if let link = (options?["configContent"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           link.hasPrefix("vless://")
        {
            return link
        }
        // No (or invalid) explicit options — this happens when the system
        // relaunches the extension itself (e.g. on-demand, or after the app
        // process isn't running): NetworkExtension re-invokes startTunnel with
        // the persisted protocolConfiguration instead of fresh options. Fall
        // back to that, mirroring ExtensionProvider's persisted-start-options
        // pattern but reading from the profile's own persisted provider
        // configuration rather than a separate snapshot file, since this
        // provider has no sing-box-style multi-field options to persist beyond
        // the single link.
        if let proto = protocolConfiguration as? NETunnelProviderProtocol,
           let link = (proto.providerConfiguration?["configContent"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           link.hasPrefix("vless://")
        {
            return link
        }
        throw ExtensionStartupError("(packet-tunnel) error: missing or invalid vless link in tunnel options")
    }

    // MARK: - Bring up / tear down

    private func bringUp(vlessLink: String) async throws {
        try await setTunnelNetworkSettings(Self.buildNetworkSettings())

        guard let fd = Self.findTunnelFileDescriptor(packetFlow: packetFlow) else {
            throw ExtensionStartupError("(packet-tunnel) error: could not find tunnel file descriptor")
        }
        tunFd = fd

        try startEngine(vlessLink: vlessLink)
        try startHevSocks5Tunnel(tunFd: fd)
    }

    private func tearDown() async {
        stopHevSocks5Tunnel()
        stopEngine()
        tunFd = -1
        currentVlessLink = nil
    }

    /// Switches the active server without tearing down the TUN interface
    /// itself: only xray-core (new outbound target) and hev-socks5-tunnel
    /// (needs restarting against the same tun fd, since hev's process-wide
    /// quit/start is not designed to swap targets live) are recycled.
    /// `reasserting` mirrors the sing-box provider's `reloadService`, so the
    /// app/UI sees the standard NetworkExtension "reconnecting" state for the
    /// duration of the swap rather than a spurious disconnect.
    private func reload(vlessLink: String) async throws {
        guard tunFd >= 0 else {
            throw ExtensionStartupError("(packet-tunnel) error: reload requested with no active tunnel")
        }
        reasserting = true
        defer { reasserting = false }

        stopHevSocks5Tunnel()
        stopEngine()

        try startEngine(vlessLink: vlessLink)
        try startHevSocks5Tunnel(tunFd: tunFd)
        currentVlessLink = vlessLink
        Self.logger.info("(packet-tunnel) reloaded with new server")
    }

    // MARK: - xray-core lifecycle

    private func startEngine(vlessLink: String) throws {
        guard let newEngine = XraymobileNewEngine() else {
            throw ExtensionStartupError("(packet-tunnel) error: failed to allocate xray-core engine")
        }
        // XraymobileEngine.start(_:socksPort:error:)'s trailing NSError** is
        // bridged by Swift into a throwing function with no `error:` argument
        // and a Void (not Bool) return — not the raw Objective-C shape.
        do {
            try newEngine.start(vlessLink, socksPort: socksPort)
        } catch {
            throw ExtensionStartupError("(packet-tunnel) error: xray-core start failed: \(error.localizedDescription)")
        }
        engine = newEngine
    }

    private func stopEngine() {
        guard let engine else { return }
        do {
            try engine.stop()
        } catch {
            Self.logger.error("(packet-tunnel) xray-core stop error: \(error.localizedDescription)")
        }
        self.engine = nil
    }

    // MARK: - hev-socks5-tunnel (tun2socks) lifecycle

    /// `hev_socks5_tunnel_main_from_str` blocks the calling thread until
    /// `hev_socks5_tunnel_quit()` is called or a fatal error occurs, so it
    /// must run off the extension's main thread. `stopHevSocks5Tunnel` blocks
    /// (briefly) on `hevStoppedSemaphore` so callers can rely on hev being
    /// fully torn down — not just asked to stop — before proceeding (e.g.
    /// before starting a new instance during `reload`, or before this
    /// provider's own `stopTunnel` returns).
    private func startHevSocks5Tunnel(tunFd: Int32) throws {
        let configBytes = Array(Self.buildHevConfig(socksPort: socksPort).utf8)

        let thread = Thread { [weak self] in
            let result = configBytes.withUnsafeBufferPointer { buffer -> Int32 in
                hev_socks5_tunnel_main_from_str(buffer.baseAddress, UInt32(buffer.count), tunFd)
            }
            if result != 0 {
                Self.logger.error("(packet-tunnel) hev-socks5-tunnel exited with code \(result)")
            }
            self?.hevStoppedSemaphore.signal()
        }
        thread.name = "hev-socks5-tunnel"
        thread.stackSize = 256 * 1024
        thread.start()
        hevThread = thread
    }

    private func stopHevSocks5Tunnel() {
        guard hevThread != nil else { return }
        hev_socks5_tunnel_quit()
        // hev's own run loop exits promptly after quit(); this bounds how long
        // teardown can block (e.g. during stopTunnel, which the system itself
        // time-bounds) rather than waiting forever if something wedges.
        _ = hevStoppedSemaphore.wait(timeout: .now() + 5)
        hevThread = nil
    }

    // MARK: - Network settings

    private static func buildNetworkSettings() -> NEPacketTunnelNetworkSettings {
        // 198.18.0.0/15 is the Android client's own TUN interface range
        // (AppConfig.ROOT_TUN_ADDR_V4, HushTunnel-Android-Client) — reused here
        // for consistency across platforms; it's IANA-reserved for benchmarking
        // and never appears as a real routable destination, so it can't collide
        // with any address the tunnel needs to actually reach.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")

        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // Cloudflare — same default the Android client uses
        // (AppConfig.DNS_VPN / DNS_CLOUDFLARE_ONE_ADDRESSES).
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])

        settings.mtu = 1500
        return settings
    }

    /// hev-socks5-tunnel's own YAML config format (see
    /// third_party/hev-socks5-tunnel/README.md "Config"). `task-stack-size` /
    /// `tcp-buffer-size` / `max-session-count` follow that README's documented
    /// "Low memory usage" guidance for iOS specifically.
    private static func buildHevConfig(socksPort: Int) -> String {
        """
        tunnel:
          mtu: 1500
          ipv4: 198.18.0.1
        socks5:
          port: \(socksPort)
          address: 127.0.0.1
          udp: 'udp'
        misc:
          task-stack-size: 24576
          tcp-buffer-size: 4096
          max-session-count: 1200
          log-level: warn
        """
    }

    /// Extracts the raw POSIX file descriptor backing `NEPacketTunnelFlow`'s
    /// underlying `utun` kernel-control socket. NetworkExtension does not
    /// expose this as public API, but this exact KVC path
    /// (`packetFlow.socket.fileDescriptor`) is already used, in production, by
    /// this repo's own sing-box integration
    /// (`Library/Network/ExtensionPlatformInterface.swift:openTun0`) — reused
    /// here rather than re-deriving a second technique, since it's proven to
    /// work in this exact app. Returns nil if the private property shape ever
    /// changes under a future OS; callers must treat that as a startup error,
    /// never silently proceed without a real fd.
    private static func findTunnelFileDescriptor(packetFlow: NEPacketTunnelFlow) -> Int32? {
        packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32
    }
}
