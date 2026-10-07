import Darwin
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

    /// Go's runtime (1.14+) preempts long-running goroutines by sending
    /// themselves `SIGURG` and handling it in a runtime-installed signal
    /// handler ("asynchronous preemption"). On-device testing showed
    /// xray-core's Go runtime starting cleanly — `instance.Start()`
    /// returning, ~20 Go scheduler threads parked normally waiting on
    /// ordinary POSIX calls — immediately followed by the whole extension
    /// process receiving `SIGABRT` from the OS with no application-level
    /// crash frame at all (confirmed via real on-device crash reports: the
    /// faulting thread is just sitting idle in the XPC run loop). That
    /// signature — a signal-based mechanism the Go runtime installed
    /// clashing with how `com.apple.security.app-sandbox` /
    /// NetworkExtension's own signal/exception handling behaves — matches a
    /// known class of problem other Go-on-iOS-extension projects
    /// (WireGuard-go's iOS port among them) have hit and fixed exactly this
    /// way: force Go onto purely cooperative preemption, which doesn't
    /// install any signal handler, by setting `GODEBUG=asyncpreemptoff=1`
    /// before the Go runtime's scheduler reads it. Must happen before the
    /// first call into Go code (`XraymobileNewEngine()`/`Engine.Start` in
    /// `startEngine()` below) — setting it here, at the very top of
    /// `startTunnel`, is early enough since nothing in this file calls into
    /// XrayMobile before that point.
    private static func disableGoAsyncPreemption() {
        setenv("GODEBUG", "asyncpreemptoff=1", 1)
    }

    /// `recover()` inside `Engine.Start` (XrayMobile/engine.go) did not catch
    /// whatever is crashing this process, which means it's not a panic on
    /// the calling goroutine — most likely an internal goroutine xray-core
    /// itself spawns during `core.New`/`instance.Start`, which `recover()`
    /// on the caller's stack can never catch (Go panics only unwind their
    /// own goroutine's stack; an unrecovered one anywhere still kills the
    /// whole process). Go's own fatal/panic output goes straight to the
    /// process's raw stderr fd via a low-level `write(2, ...)` — it never
    /// goes through os_log, which is why nothing has shown up in Console/
    /// device syslog despite extensive searching. Redirect stderr to a real
    /// file in this extension's own private container (not the shared App
    /// Group, which `writeDebugMarker` below already tried and the file
    /// never actually appeared — sandbox write access differs) before any
    /// Go code runs, so whatever Go actually prints on its way down is
    /// captured somewhere readable afterward via `devicectl device info
    /// files --domain-type appDataContainer`.
    private static func redirectStderrToFile() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent("stderr_capture.log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        freopen(url.path, "a+", stderr)
        setvbuf(stderr, nil, _IONBF, 0) // unbuffered — flush every write immediately, since the process may be killed with no chance to flush
        FileHandle.standardError.write("--- stderr redirected at \(Date()) ---\n".data(using: .utf8)!)
    }

    override func startTunnel(options: [String: NSObject]?) async throws {
        Self.redirectStderrToFile()
        Self.disableGoAsyncPreemption()
        Self.writeDebugMarker("startTunnel entered, options keys: \(options?.keys.sorted() ?? [])")
        do {
            let vlessLink = try resolveVlessLink(options: options)
            Self.writeDebugMarker("resolved vless link ok, host: \(URL(string: vlessLink)?.host ?? "?")")
            if let components = URLComponents(string: vlessLink) {
                let q = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                Self.logger.info("(packet-tunnel) [step] vless params: host=\(components.host ?? "?", privacy: .public) port=\(components.port ?? -1) security=\(q["security"] ?? "?", privacy: .public) sni=\(q["sni"] ?? "?", privacy: .public) fp=\(q["fp"] ?? "?", privacy: .public) flow=\(q["flow"] ?? "?", privacy: .public) pbk.count=\(q["pbk"]?.count ?? -1) sid=\(q["sid"] ?? "?", privacy: .public)")
            }
            Self.logger.info("(packet-tunnel) starting, xray-core \(XraymobileVersion())")
            try await bringUp(vlessLink: vlessLink)
            currentVlessLink = vlessLink
            Self.writeDebugMarker("bringUp succeeded")
            Self.logger.info("(packet-tunnel) started")
        } catch {
            Self.writeDebugMarker("startTunnel threw: \(error)")
            throw error
        }
    }

    /// TEMPORARY diagnostic: NetworkExtension's os_log output isn't
    /// reachable from this sandboxed environment (no Console.app, no
    /// `idevicesyslog`), but files written to the shared App Group
    /// container ARE readable via `devicectl device info files
    /// --domain-type appGroupDataContainer`. Appends one line per call;
    /// remove once on-device testing is complete and a real log-viewing
    /// path exists.
    private static func writeDebugMarker(_ message: String) {
        let url = FilePath.sharedDirectory.appendingPathComponent("xray_debug.log")
        let line = "[\(Date())] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
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
        Self.logger.info("(packet-tunnel) [step] calling setTunnelNetworkSettings")
        try await setTunnelNetworkSettings(Self.buildNetworkSettings())
        Self.logger.info("(packet-tunnel) [step] setTunnelNetworkSettings returned")

        guard let fd = await Self.findTunnelFileDescriptorWithRetry(packetFlow: packetFlow) else {
            Self.logger.error("(packet-tunnel) [step] findTunnelFileDescriptor returned nil after retries")
            throw ExtensionStartupError("(packet-tunnel) error: could not find tunnel file descriptor")
        }
        Self.logger.info("(packet-tunnel) [step] got tun fd \(fd)")
        tunFd = fd

        Self.logger.info("(packet-tunnel) [step] calling startEngine (xray-core)")
        try startEngine(vlessLink: vlessLink)
        Self.logger.info("(packet-tunnel) [step] startEngine returned, engine.isRunning=\(self.engine?.isRunning() ?? false)")
        Self.logger.info("(packet-tunnel) [step] calling startHevSocks5Tunnel")
        try startHevSocks5Tunnel(tunFd: fd)
        Self.logger.info("(packet-tunnel) [step] startHevSocks5Tunnel returned (thread launched, not necessarily running yet)")
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
            Self.logger.info("(packet-tunnel) [step] hev-socks5-tunnel thread running, calling hev_socks5_tunnel_main_from_str with tunFd=\(tunFd)")
            let result = configBytes.withUnsafeBufferPointer { buffer -> Int32 in
                hev_socks5_tunnel_main_from_str(buffer.baseAddress, UInt32(buffer.count), tunFd)
            }
            Self.logger.info("(packet-tunnel) [step] hev_socks5_tunnel_main_from_str returned \(result)")
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

    /// Extracts the raw POSIX file descriptor backing the active `utun`
    /// kernel-control socket.
    ///
    /// The private KVC path this repo's sing-box integration tries first
    /// (`packetFlow.value(forKeyPath: "socket.fileDescriptor")`, see
    /// `Library/Network/ExtensionPlatformInterface.swift:openTun0`) does not
    /// work at all in this environment: on-device tracing (device syslog,
    /// filtered on the extension's own logs) showed `startTunnelWithOptions`
    /// and `setTunnelNetworkSettings` both succeeding every time, immediately
    /// followed by this KVC lookup returning nil on every attempt across a
    /// 2-second retry window — not an occasional race, a hard, consistent
    /// failure. Polling longer does not help: sing-box's own code only
    /// tolerates this because it falls back to `LibboxGetTunnelFileDescriptor()`,
    /// an internal Go-side mechanism specific to Libbox with no equivalent
    /// here, so the KVC path was never actually load-bearing in that
    /// reference implementation either.
    ///
    /// This uses the public, documented technique instead (the normal way to
    /// do this on Apple platforms without private API, used by several real
    /// Network Extension clients): every `utun` interface's name is
    /// retrievable from its already-open kernel-control socket via
    /// `getsockopt(fd, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, ...)` — ordinary
    /// POSIX socket options, not the `<sys/kern_control.h>` struct layouts
    /// (`ctl_info`/`sockaddr_ctl`/`CTLIOCGINFO`) that approach would need,
    /// none of which are bridged into Swift's `Darwin` module without a
    /// custom bridging header. Scan the process's own file descriptor table
    /// for the one whose interface name starts with "utun".
    private static let sysprotoControl: Int32 = 2 // SYSPROTO_CONTROL
    private static let utunOptIfname: Int32 = 2 // UTUN_OPT_IFNAME

    private static func findTunnelFileDescriptor() -> Int32? {
        var nameBuffer = [UInt8](repeating: 0, count: Int(IFNAMSIZ))
        for fd: Int32 in 0 ... 1024 {
            var length = socklen_t(nameBuffer.count)
            let result = getsockopt(fd, sysprotoControl, utunOptIfname, &nameBuffer, &length)
            guard result == 0 else { continue }
            let name = String(cString: nameBuffer)
            if name.hasPrefix("utun") {
                return fd
            }
        }
        return nil
    }

    /// `findTunnelFileDescriptor()`'s scan is synchronous and has been
    /// reliable in on-device testing immediately after
    /// `setTunnelNetworkSettings` returns, but a short retry window is kept
    /// — cheap insurance against the kernel-control socket taking a beat to
    /// appear under load, without masking a genuine, permanent absence (this
    /// still fails after the deadline rather than hanging indefinitely).
    private static func findTunnelFileDescriptorWithRetry(
        packetFlow _: NEPacketTunnelFlow,
        timeout: TimeInterval = 2.0,
        pollInterval: UInt64 = 50_000_000 // 50ms
    ) async -> Int32? {
        let deadline = Date().addingTimeInterval(timeout)
        var attempt = 0
        while Date() < deadline {
            attempt += 1
            if let fd = findTunnelFileDescriptor() {
                writeDebugMarker("findTunnelFileDescriptorWithRetry: got fd \(fd) via utun_control scan on attempt \(attempt)")
                return fd
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }
        writeDebugMarker("findTunnelFileDescriptorWithRetry: timed out after \(attempt) attempts")
        return nil
    }
}
