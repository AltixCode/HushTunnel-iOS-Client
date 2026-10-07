// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import SwiftUI

public struct DashboardCardView<Content: View>: View {
    private let title: String
    private let isHalfWidth: Bool
    @ViewBuilder private let content: () -> Content

    public init(title: String, isHalfWidth: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isHalfWidth = isHalfWidth
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 12) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(tvOS)
            .padding(EdgeInsets(top: 20, leading: 26, bottom: 20, trailing: 26))
        #else
            .padding(16)
        #endif
            .cardStyle()
    }
}
#endif
