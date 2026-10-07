import Foundation
#if !os(iOS)
    import Libbox
#endif
import Library

/// Bridges the backend's subscription into the active engine's real
/// remote-profile pipeline, so the user never sees a profile list or "add
/// profile" screen — this runs invisibly after login/order, then the real
/// `ExtensionProfile` (NetworkExtension) is used to actually connect.
/// Mirrors the Android fork's `ProvisionHelper.provisionSubscription`.
///
/// iOS and macOS/tvOS fetch different representations of the same
/// subscription, because they run different tunnel engines:
///
/// - macOS/tvOS (SFM/SFT) still run sing-box (`Library/Network/ExtensionProvider.swift`,
///   unchanged), which needs a complete sing-box config document — the
///   backend's `?format=sing-box` query param on the same subscription URL
///   returns exactly that (see `buildSingBoxConfig` in the
///   HushTunnel-Billing-Dashboard web repo), validated here via
///   `LibboxCheckConfig`.
/// - iOS (SFI) runs xray-core + hev-socks5-tunnel instead (GPLv3 sing-box
///   replaced with MPL-2.0/MIT engines for App Store distribution — see
///   `Extension/PacketTunnelProvider.swift`), which consumes the backend's
///   *default* subscription format directly: a single plain `vless://` link
///   (the same format HushTunnel's own Android client, and most v2ray-family
///   clients, already consume) — no `?format=sing-box`, no `LibboxCheckConfig`.
public enum ProvisionHelper {
    public static let profileName = "HushTunnel"

    /// Points the app's single managed profile at `subscriptionUrl`, creating
    /// it on first use or updating it if it already exists, then selects it
    /// as the active profile. Follows the exact same create-remote-profile
    /// pattern as `NewProfileViewModel.createProfileBackground()`'s `.remote`
    /// branch — reusing the app's own real, existing profile pipeline rather
    /// than a bespoke one.
    public static func provisionSubscription(
        subscriptionUrl: String,
        preferredServerId: String? = nil,
        preferredServerHost: String? = nil,
        reloadRunningProfile: Bool = true
    ) async throws {
        #if os(iOS)
            // Explicit, not inferred: the backend's format auto-detection
            // (lib/subscription-format.ts) falls back to sniffing "sing-box"
            // out of the request's User-Agent when no `?format=` is given —
            // and `Library/Network/HTTPClient.swift` wraps Libbox's Go HTTP
            // client, which does not actually honor
            // `request.setUserAgent(...)` the way `HTTPClient.userAgent`
            // assumes (confirmed: even after making that string iOS-aware,
            // the backend kept receiving a sing-box-matching UA and serving
            // the JSON config format instead of plain links). Any value
            // other than "json"/"sing-box" selects the base64 branch
            // unconditionally — using that instead of fighting Libbox's HTTP
            // stack.
            var baseRemoteURL = URL(string: subscriptionUrl)?.appendingQueryItem(name: "format", value: "base64")
        #else
            var baseRemoteURL = URL(string: subscriptionUrl)?.appendingQueryItem(name: "format", value: "sing-box")
        #endif
        if let preferred = preferredServerId, !preferred.isEmpty {
            baseRemoteURL = baseRemoteURL?.appendingQueryItem(name: "server", value: preferred)
        }
        guard let remoteURL = baseRemoteURL else {
            throw NSError(domain: "ProvisionHelper", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid subscription URL"])
        }

        // Download and validate the requested server configuration before
        // changing the managed profile's URL. Otherwise a failed refresh can
        // leave the UI pointing at one server while the config file still
        // contains the previously selected server.
        let rawContent = try await HTTPClient.getStringAsync(remoteURL.absoluteString)
        let contentToStore: String
        #if os(iOS)
            // The backend's default subscription format follows the standard
            // v2ray-ecosystem convention: the body is base64 (not a literal
            // "vless://..." string) decoding to one or more newline-separated
            // share links — the same format HushTunnel's Android client (a
            // v2rayNG fork) already consumes, and (unlike the sing-box/json
            // format, which does respect `?server=`) it is NOT pre-filtered
            // to the requested server — it always lists every active server.
            // Match client-side by host, the same way the Android client's
            // own `ProvisionHelper.selectServerByNode` does.
            contentToStore = try Self.extractVlessLink(from: rawContent, preferredHost: preferredServerHost)
        #else
            contentToStore = rawContent
            try await BlockingIO.run {
                var error: NSError?
                LibboxCheckConfig(contentToStore, &error)
                if let error {
                    throw error
                }
            }
        #endif

        if let existing = try await ProfileManager.get(by: profileName) {
            existing.remoteURL = remoteURL.absoluteString
            try await ProfileManager.update(existing)
            try await existing.updateRemoteProfile(
                content: contentToStore,
                reloadIfSelected: reloadRunningProfile
            )
            await SharedPreferences.selectedProfileID.set(existing.mustID)
            ServerSelectionStore.selectedServerID = preferredServerId
            return
        }

        let nextProfileID = try await ProfileManager.nextID()
        let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
        let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
        try await BlockingIO.run {
            try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
            try contentToStore.write(to: profileConfig, atomically: true, encoding: .utf8)
        }

        let profile = Profile(
            name: profileName,
            type: .remote,
            path: "configs/config_\(nextProfileID).json",
            remoteURL: remoteURL.absoluteString,
            autoUpdate: true,
            autoUpdateInterval: 60,
            lastUpdated: .now
        )
        try await ProfileManager.create(profile)
        await SharedPreferences.selectedProfileID.set(profile.mustID)
        ServerSelectionStore.selectedServerID = preferredServerId
    }

    #if os(iOS)
        /// Extracts a single `vless://` share link from a subscription body.
        /// Handles both representations the backend may return:
        ///   - base64: the whole body is base64 (standard-or-URL-safe,
        ///     optionally unpadded), decoding to one or more newline-separated
        ///     share links — this format lists *every* active server (it does
        ///     not filter by `?server=` the way the sing-box/json format
        ///     does), so `preferredHost` is used to pick the right one.
        ///   - plain: the body is already a bare `vless://...` link.
        /// Throws if neither interpretation yields any valid link.
        static func extractVlessLink(from rawContent: String, preferredHost: String?) throws -> String {
            let trimmed = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)

            func vlessLines(in text: String) -> [String] {
                text
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.hasPrefix("vless://") }
            }

            let candidates: [String]
            if !vlessLines(in: trimmed).isEmpty {
                candidates = vlessLines(in: trimmed)
            } else if let decoded = Self.base64Decode(trimmed) {
                candidates = vlessLines(in: decoded)
            } else {
                candidates = []
            }

            guard !candidates.isEmpty else {
                let preview = String(trimmed.prefix(80))
                throw NSError(domain: "ProvisionHelper", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Subscription did not return a valid vless:// link (got \(trimmed.count) chars, starting: \(preview))",
                ])
            }

            if let preferredHost, !preferredHost.isEmpty {
                if let match = candidates.first(where: { URL(string: $0)?.host?.caseInsensitiveCompare(preferredHost) == .orderedSame }) {
                    return match
                }
            }

            return candidates[0]
        }

        /// Decodes standard or URL-safe base64, with or without padding —
        /// subscription services are inconsistent about which variant they
        /// emit, and `Data(base64Encoded:)` alone only accepts padded
        /// standard base64.
        private static func base64Decode(_ string: String) -> String? {
            var normalized = string
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let remainder = normalized.count % 4
            if remainder > 0 {
                normalized += String(repeating: "=", count: 4 - remainder)
            }
            guard let data = Data(base64Encoded: normalized) else { return nil }
            return String(data: data, encoding: .utf8)
        }
    #endif
}

/// Persists the server that was successfully written to the managed profile.
/// A saved value is always revalidated against the latest server list before
/// it is displayed or provisioned.
public enum ServerSelectionStore {
    private static let key = "io.hushtunnel.selected-server-id"

    public static var selectedServerID: String? {
        get { UserDefaults.standard.string(forKey: key)?.nilIfBlank }
        set {
            if let newValue = newValue?.nilIfBlank {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    public static func resolve(
        servers: [ServerNodeItem],
        currentServerID: String? = nil
    ) -> ServerNodeItem? {
        if let currentServerID,
           let current = servers.first(where: { $0.id == currentServerID })
        {
            return current
        }
        if let saved = selectedServerID,
           let persisted = servers.first(where: { $0.id == saved })
        {
            return persisted
        }
        return servers.first(where: { $0.isDefault == true }) ?? servers.first
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension URL {
    func appendingQueryItem(name: String, value: String) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: name, value: value))
        components.queryItems = items
        return components.url
    }
}
