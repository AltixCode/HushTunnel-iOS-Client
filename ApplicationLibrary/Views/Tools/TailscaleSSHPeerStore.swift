// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import Library
import SwiftUI

@MainActor
public final class TailscaleSSHPeerStore: ObservableObject {
    @Published public var sshPeers: [TailscaleSSHPeerEntry] = []
    @Published public var quickConnectPeerIDs: Set<String> = []

    public var quickConnectPeers: [TailscaleSSHPeerEntry] {
        sshPeers.filter { quickConnectPeerIDs.contains($0.stableID) }
    }

    public init() {}
}
#endif
