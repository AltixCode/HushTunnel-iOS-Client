// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import SwiftUI

public struct DashboardCardHeader: View {
    private let icon: String
    private let title: LocalizedStringKey

    public init(icon: String, title: LocalizedStringKey) {
        self.icon = icon
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.primary)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
    }
}
#endif
