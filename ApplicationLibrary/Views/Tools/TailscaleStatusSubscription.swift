// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import Library
import SwiftUI

public extension View {
    func tailscaleStatusSubscription(
        _ viewModel: TailscaleStatusViewModel,
        environments: ExtensionEnvironments,
        peerStore: TailscaleSSHPeerStore
    ) -> some View {
        modifier(TailscaleStatusSubscriptionModifier(environments: environments, peerStore: peerStore, viewModel: viewModel))
    }
}

private struct TailscaleStatusSubscriptionModifier: ViewModifier {
    @ObservedObject var environments: ExtensionEnvironments
    let peerStore: TailscaleSSHPeerStore
    let viewModel: TailscaleStatusViewModel

    func body(content: Content) -> some View {
        content
            .onAppear {
                viewModel.peerStore = peerStore
                viewModel.environments = environments
            }
            .modifier(ConnectionLifecycleObserver(
                profile: environments.extensionProfile,
                remoteServerID: environments.remoteServer?.id,
                onActive: { viewModel.subscribe() },
                onInactive: { viewModel.cancel() }
            ))
    }
}
#endif
