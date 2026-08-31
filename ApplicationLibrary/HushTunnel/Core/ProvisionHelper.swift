import Foundation
import Libbox
import Library

/// Bridges the backend's subscription into sing-box's real remote-profile
/// pipeline, so the user never sees a profile list or "add profile" screen —
/// this runs invisibly after login/order, then the real `ExtensionProfile`
/// (NetworkExtension) is used to actually connect. Mirrors the Android fork's
/// `ProvisionHelper.provisionSubscription`.
///
/// The backend's default subscription format (base64 vless:// links, for
/// v2ray-family clients like Android's v2rayNG) is not something sing-box's
/// `LibboxCheckConfig` can parse — it needs a complete sing-box config
/// document. `?format=sing-box` on the same subscription URL returns exactly
/// that (see `buildSingBoxConfig` in the vpn-billing-dashboard web repo,
/// schema-verified against the real `sing-box check` CLI).
public enum ProvisionHelper {
    public static let profileName = "HushTunnel"

    /// Points the app's single managed profile at `subscriptionUrl`, creating
    /// it on first use or updating it if it already exists, then selects it
    /// as the active profile. Follows the exact same create-remote-profile
    /// pattern as `NewProfileViewModel.createProfileBackground()`'s `.remote`
    /// branch — reusing the app's own real, existing profile pipeline rather
    /// than a bespoke one.
    public static func provisionSubscription(subscriptionUrl: String) async throws {
        guard let remoteURL = URL(string: subscriptionUrl)?.appendingQueryItem(name: "format", value: "sing-box") else {
            throw NSError(domain: "ProvisionHelper", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid subscription URL"])
        }

        if let existing = try await ProfileManager.get(by: profileName) {
            existing.remoteURL = remoteURL.absoluteString
            try await ProfileManager.update(existing)
            try await existing.updateRemoteProfile()
            await SharedPreferences.selectedProfileID.set(existing.mustID)
            return
        }

        let remoteContent = try await HTTPClient.getStringAsync(remoteURL.absoluteString)
        try await BlockingIO.run {
            var error: NSError?
            LibboxCheckConfig(remoteContent, &error)
            if let error {
                throw error
            }
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
