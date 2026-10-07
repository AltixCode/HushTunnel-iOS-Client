// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import Library
import SwiftUI

public struct HTTPProxyCard: View {
    @EnvironmentObject private var profile: ExtensionProfile
    @Binding private var systemProxyAvailable: Bool
    @Binding private var systemProxyEnabled: Bool
    private let onToggle: (Bool) async -> Void

    public init(
        systemProxyAvailable: Binding<Bool>,
        systemProxyEnabled: Binding<Bool>,
        onToggle: @escaping (Bool) async -> Void
    ) {
        _systemProxyAvailable = systemProxyAvailable
        _systemProxyEnabled = systemProxyEnabled
        self.onToggle = onToggle
    }

    public var body: some View {
        DashboardCardView(title: "", isHalfWidth: false) {
            HStack {
                DashboardCardHeader(icon: "network", title: "System HTTP Proxy")
                Spacer()
                Toggle(isOn: $systemProxyEnabled) {}
                    .labelsHidden()
                #if os(macOS)
                    .toggleStyle(.switch)
                #endif
                    .onChangeCompat(of: systemProxyEnabled) { newValue in
                        Task {
                            await onToggle(newValue)
                        }
                    }
            }
        }
    }
}
#endif
