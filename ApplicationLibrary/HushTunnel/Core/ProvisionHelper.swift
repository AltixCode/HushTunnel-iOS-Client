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
        reloadRunningProfile: Bool = true
    ) async throws {
        #if os(iOS)
            var baseRemoteURL = URL(string: subscriptionUrl)
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
        let remoteContent = try await HTTPClient.getStringAsync(remoteURL.absoluteString)
        #if os(iOS)
            let trimmed = remoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("vless://"), URL(string: trimmed) != nil else {
                throw NSError(domain: "ProvisionHelper", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Subscription did not return a valid vless:// link",
                ])
            }
        #else
            try await BlockingIO.run {
                var error: NSError?
                LibboxCheckConfig(remoteContent, &error)
                if let error {
                    throw error
                }
            }
        #endif

        if let existing = try await ProfileManager.get(by: profileName) {
            existing.remoteURL = remoteURL.absoluteString
            try await ProfileManager.update(existing)
            try await existing.updateRemoteProfile(
                content: remoteContent,
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
            try remoteContent.write(to: profileConfig, atomically: true, encoding: .utf8)
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
