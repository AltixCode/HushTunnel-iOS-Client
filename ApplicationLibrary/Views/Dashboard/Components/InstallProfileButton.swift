// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import Library
import SwiftUI

@MainActor
public struct InstallProfileButton: View {
    @State private var alert: AlertState?

    private let callback: () async -> Void
    public init(_ callback: @escaping (() async -> Void)) {
        self.callback = callback
    }

    public var body: some View {
        FormButton {
            Task {
                await installProfile()
            }
        } label: {
            Label("Install Network Extension", systemImage: "lock.doc.fill")
        }
        .alert($alert)
    }

    private func installProfile() async {
        do {
            try await ExtensionProfile.install()
            await callback()
        } catch {
            alert = AlertState(action: "install network extension", error: error)
        }
    }
}
#endif
